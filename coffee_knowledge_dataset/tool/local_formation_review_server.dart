import 'dart:convert';
import 'dart:io';

import 'src/k6a_dataset.dart';
import 'src/lf1_profiles.dart';
import 'src/lf1_review.dart';

Future<void> main(List<String> arguments) async {
  final options = Lf1ReviewServerOptions.parse(arguments);
  final application = await Lf1ReviewApplication.load(options);
  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    options.port,
  );
  stdout.writeln('LF-1 review: http://127.0.0.1:${server.port}/');
  await for (final request in server) {
    await application.handle(request);
  }
}

final class Lf1ReviewServerOptions {
  const Lf1ReviewServerOptions({
    required this.datasetRoot,
    required this.manifestPath,
    required this.freezePath,
    required this.captureGroupsPath,
    required this.reportPath,
    required this.outputDirectory,
    required this.repositoryRoot,
    required this.port,
  });

  factory Lf1ReviewServerOptions.parse(List<String> arguments) {
    const flags = {
      '--dataset',
      '--manifest',
      '--freeze',
      '--capture-groups',
      '--report',
      '--output',
      '--repository-root',
      '--port',
    };
    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index += 2) {
      final flag = arguments[index];
      if (!flags.contains(flag)) {
        throw FormatException('Unknown LF-1 review flag: $flag.');
      }
      if (values.containsKey(flag)) {
        throw FormatException('Duplicate LF-1 review flag: $flag.');
      }
      if (index + 1 >= arguments.length || arguments[index + 1].isEmpty) {
        throw FormatException('Missing value for LF-1 review flag: $flag.');
      }
      values[flag] = arguments[index + 1];
    }
    for (final flag in const {
      '--dataset',
      '--manifest',
      '--freeze',
      '--capture-groups',
      '--report',
      '--output',
      '--repository-root',
    }) {
      if (!values.containsKey(flag)) {
        throw FormatException('Missing required LF-1 review flag: $flag.');
      }
    }
    final port = values.containsKey('--port')
        ? int.tryParse(values['--port']!)
        : 8766;
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException('--port must be between 1 and 65535.');
    }
    return Lf1ReviewServerOptions(
      datasetRoot: values['--dataset']!,
      manifestPath: values['--manifest']!,
      freezePath: values['--freeze']!,
      captureGroupsPath: values['--capture-groups']!,
      reportPath: values['--report']!,
      outputDirectory: values['--output']!,
      repositoryRoot: values['--repository-root']!,
      port: port,
    );
  }

  final String datasetRoot;
  final String manifestPath;
  final String freezePath;
  final String captureGroupsPath;
  final String reportPath;
  final String outputDirectory;
  final String repositoryRoot;
  final int port;
}

final class Lf1ReviewImage {
  const Lf1ReviewImage({
    required this.sourceId,
    required this.surfaceType,
    required this.captureGroupId,
    required this.path,
    required this.format,
  });

  final String sourceId;
  final String surfaceType;
  final String captureGroupId;
  final String path;
  final String format;
}

final class Lf1ReviewApplication {
  Lf1ReviewApplication._({
    required this.options,
    required this.observations,
    required this.images,
    required Lf1AnnotationSet annotations,
  }) : _annotations = annotations;

  static Future<Lf1ReviewApplication> load(
    Lf1ReviewServerOptions options,
  ) async {
    _rejectRepositoryOutput(options.outputDirectory, options.repositoryRoot);
    final dataset = await const K6aDatasetPreflight().validate(
      datasetRoot: options.datasetRoot,
      manifestPath: options.manifestPath,
      freezePath: options.freezePath,
    );
    final observations = Lf1ObservationIndex.parse(
      await File(options.reportPath).readAsString(),
    );
    final groups = _parseCaptureGroups(
      await File(options.captureGroupsPath).readAsString(),
    );
    final entriesById = {
      for (final entry in dataset.entries) entry.sourceId: entry,
    };
    final images = <Lf1ReviewImage>[];
    for (final sourceId in lf1ReviewPanelSourceIds) {
      final entry = entriesById[sourceId];
      final captureGroupId = groups[sourceId];
      if (entry == null || !entry.enabled || captureGroupId == null) {
        throw FormatException('LF-1 panel source is unavailable: $sourceId.');
      }
      for (final profileId in observations.profileIds) {
        observations.observation(profileId, sourceId);
      }
      images.add(
        Lf1ReviewImage(
          sourceId: sourceId,
          surfaceType: entry.surfaceType.name,
          captureGroupId: captureGroupId,
          path: _resolveRelativePath(options.datasetRoot, entry.relativePath),
          format: entry.format,
        ),
      );
    }
    final annotationPath = _join(
      options.outputDirectory,
      'local_formation_annotations.json',
    );
    final annotationSource = await File(annotationPath).exists()
        ? await File(annotationPath).readAsString()
        : jsonEncode({
            'schemaVersion': '1.0',
            'researchId': observations.researchId,
            'annotations': <Object>[],
          });
    final annotations = const Lf1AnnotationCodec().parse(
      source: annotationSource,
      observations: observations,
      panelSourceIds: lf1ReviewPanelSourceIds.toSet(),
    );
    return Lf1ReviewApplication._(
      options: options,
      observations: observations,
      images: List<Lf1ReviewImage>.unmodifiable(images),
      annotations: annotations,
    );
  }

  final Lf1ReviewServerOptions options;
  final Lf1ObservationIndex observations;
  final List<Lf1ReviewImage> images;
  Lf1AnnotationSet _annotations;

  Future<void> handle(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/') {
        return _text(request.response, _page, ContentType.html);
      }
      if (request.method == 'GET' && request.uri.path == '/api/state') {
        return _json(request.response, _state());
      }
      if (request.method == 'GET' &&
          request.uri.pathSegments.length == 2 &&
          request.uri.pathSegments.first == 'image') {
        return _image(request.response, request.uri.pathSegments.last);
      }
      if (request.method == 'POST' && request.uri.path == '/api/annotations') {
        final body = await utf8.decoder.bind(request).join();
        if (body.length > 5 * 1024 * 1024) {
          request.response.statusCode = HttpStatus.requestEntityTooLarge;
          return _json(request.response, {'error': 'Request is too large.'});
        }
        final annotations = const Lf1AnnotationCodec().parse(
          source: body,
          observations: observations,
          panelSourceIds: lf1ReviewPanelSourceIds.toSet(),
        );
        final evaluation = const Lf1Evaluator().evaluate(
          observations: observations,
          annotationSet: annotations,
        );
        await const Lf1ReviewWriter().write(
          outputDirectory: options.outputDirectory,
          repositoryRoot: options.repositoryRoot,
          annotations: annotations,
          evaluation: evaluation,
        );
        _annotations = annotations;
        return _json(request.response, {
          'saved': true,
          'evaluation': evaluation.toJson(),
        });
      }
      request.response.statusCode = HttpStatus.notFound;
      return _json(request.response, {'error': 'Not found.'});
    } on FormatException catch (error) {
      request.response.statusCode = HttpStatus.badRequest;
      return _json(request.response, {'error': error.message});
    } on FileSystemException {
      request.response.statusCode = HttpStatus.internalServerError;
      return _json(request.response, {
        'error': 'Research file operation failed.',
      });
    } on Object {
      request.response.statusCode = HttpStatus.internalServerError;
      return _json(request.response, {'error': 'LF-1 review request failed.'});
    }
  }

  Map<String, Object?> _state() {
    final evaluation = const Lf1Evaluator().evaluate(
      observations: observations,
      annotationSet: _annotations,
    );
    return {
      'researchId': observations.researchId,
      'profiles': observations.profileIds,
      'images': [
        for (final image in images)
          {
            'sourceId': image.sourceId,
            'surfaceType': image.surfaceType,
            'captureGroupId': image.captureGroupId,
            'imageUrl': '/image/${image.sourceId}',
          },
      ],
      'observations': [
        for (final image in images)
          for (final profileId in observations.profileIds)
            {
              'sourceId': image.sourceId,
              'profileId': profileId,
              'candidates': observations
                  .observation(profileId, image.sourceId)
                  .candidates
                  .map((candidate) => candidate.toJson())
                  .toList(),
            },
      ],
      'annotations': _annotations.annotations
          .map((annotation) => annotation.toJson())
          .toList(),
      'evaluation': evaluation.toJson(),
    };
  }

  Future<void> _image(HttpResponse response, String sourceId) async {
    final image = images
        .where((value) => value.sourceId == sourceId)
        .firstOrNull;
    if (image == null) {
      response.statusCode = HttpStatus.notFound;
      return _json(response, {'error': 'Unknown image.'});
    }
    response.headers.contentType = switch (image.format) {
      'png' => ContentType('image', 'png'),
      _ => ContentType('image', 'jpeg'),
    };
    await response.addStream(File(image.path).openRead());
    await response.close();
  }
}

Future<void> _json(HttpResponse response, Object value) {
  return _text(
    response,
    jsonEncode(value),
    ContentType('application', 'json', charset: 'utf-8'),
  );
}

Future<void> _text(
  HttpResponse response,
  String value,
  ContentType contentType,
) async {
  response.headers.contentType = contentType;
  response.write(value);
  await response.close();
}

Map<String, String> _parseCaptureGroups(String source) {
  final rows = _parseCsv(source);
  if (rows.isEmpty) throw const FormatException('Capture group CSV is empty.');
  const expected = [
    'captureGroupId',
    'sourceId',
    'originalIndex',
    'surfaceType',
    'reviewStatus',
    'groupBasis',
    'notes',
  ];
  if (rows.first.length != expected.length ||
      !List.generate(
        expected.length,
        (index) => rows.first[index] == expected[index],
      ).every((value) => value)) {
    throw const FormatException('Capture group CSV header is invalid.');
  }
  final result = <String, String>{};
  for (final row in rows.skip(1)) {
    if (row.length != expected.length) {
      throw const FormatException('Capture group CSV row is invalid.');
    }
    final sourceId = row[1];
    if (result.containsKey(sourceId)) {
      throw FormatException('Duplicate capture group source: $sourceId.');
    }
    result[sourceId] = row[0];
  }
  return Map<String, String>.unmodifiable(result);
}

List<List<String>> _parseCsv(String source) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var index = 0; index < source.length; index++) {
    final code = source[index];
    if (quoted) {
      if (code == '"') {
        if (index + 1 < source.length && source[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = false;
        }
      } else {
        field.write(code);
      }
      continue;
    }
    if (code == '"' && field.isEmpty) {
      quoted = true;
    } else if (code == ',') {
      row.add(field.toString());
      field.clear();
    } else if (code == '\r' || code == '\n') {
      if (code == '\r' &&
          index + 1 < source.length &&
          source[index + 1] == '\n') {
        index++;
      }
      row.add(field.toString());
      field.clear();
      if (row.any((value) => value.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(code);
    }
  }
  if (quoted) throw const FormatException('Capture group CSV is malformed.');
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

String _resolveRelativePath(String root, String relativePath) {
  final rootPath = Directory(root).absolute.path;
  final resolved = File(
    [
      rootPath,
      relativePath.replaceAll('/', Platform.pathSeparator),
    ].join(Platform.pathSeparator),
  ).absolute.path;
  final prefix = rootPath.endsWith(Platform.pathSeparator)
      ? rootPath
      : '$rootPath${Platform.pathSeparator}';
  if (!resolved.toLowerCase().startsWith(prefix.toLowerCase())) {
    throw const FormatException('Dataset image path escapes its root.');
  }
  return resolved;
}

void _rejectRepositoryOutput(String output, String repositoryRoot) {
  final outputPath = Directory(output).absolute.path.toLowerCase();
  final repositoryPath = Directory(repositoryRoot).absolute.path.toLowerCase();
  final prefix = repositoryPath.endsWith(Platform.pathSeparator)
      ? repositoryPath
      : '$repositoryPath${Platform.pathSeparator}';
  if (outputPath == repositoryPath || outputPath.startsWith(prefix)) {
    throw const FormatException(
      'LF-1 output must remain outside the repository.',
    );
  }
}

String _join(String directory, String filename) {
  return [directory, filename].join(Platform.pathSeparator);
}

const String _page = r'''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Atlas LF-1 Review</title>
<style>
:root{color-scheme:dark;--bg:#10171b;--panel:#172126;--line:#34454d;--text:#edf3f4;--muted:#9fb0b7;--accent:#25a4a0;--warn:#f0b24a;--candidate:#63b3ff;--annotation:#ffcf5b}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px Arial,sans-serif;height:100vh;overflow:hidden}button,select,input,textarea{font:inherit;color:inherit;background:#0f181c;border:1px solid var(--line);border-radius:4px}button{padding:8px 10px;cursor:pointer}button.active,.primary{background:var(--accent);border-color:var(--accent);font-weight:700}.app{display:grid;grid-template-columns:240px minmax(0,1fr) 330px;height:100vh}.sidebar,.inspector{background:var(--panel);overflow:auto}.sidebar{border-right:1px solid var(--line)}.inspector{border-left:1px solid var(--line);padding:14px}.brand{padding:15px;border-bottom:1px solid var(--line);font-weight:700}.source{width:100%;border:0;border-bottom:1px solid #27363c;border-radius:0;text-align:left;padding:11px 13px;background:transparent}.source.active{background:#21363b}.source small{display:block;color:var(--muted);margin-top:3px}.workspace{display:grid;grid-template-rows:auto minmax(0,1fr);min-width:0;min-height:0}.toolbar{display:flex;align-items:center;gap:8px;padding:8px 12px;background:#1b282e;border-bottom:1px solid var(--line);flex-wrap:wrap}.toolbar select{padding:7px;min-width:230px}.legend{display:inline-flex;align-items:center;gap:5px;color:var(--muted);font-size:12px;white-space:nowrap}.swatch{width:11px;height:11px;border:2px solid currentColor}.swatch.annotation{color:var(--annotation)}.swatch.candidate{color:var(--candidate)}.canvas-wrap{display:grid;place-items:center;overflow:auto;padding:14px;min-width:0;min-height:0}canvas{max-width:100%;max-height:calc(100vh - 110px);background:#0a0f11;box-shadow:0 0 0 1px var(--line)}h2,h3{margin:0 0 12px;font-size:16px}.field{margin:0 0 12px}.field label{display:block;color:var(--muted);font-size:12px;margin-bottom:5px}.field input,.field select,.field textarea{width:100%;padding:8px}.field textarea{height:72px;resize:vertical}.row{display:flex;gap:7px}.row>*{flex:1}.candidate{border-top:1px solid var(--line);padding:9px 0}.candidate-head{display:flex;justify-content:space-between;margin-bottom:6px}.candidate select{width:100%;padding:6px}.empty{color:var(--muted);padding:12px 0}.status{margin-left:auto;color:var(--muted)}.status.dirty{color:var(--warn)}.danger{color:#ff8a86}.summary{font-size:12px;color:var(--muted);margin:8px 0 14px}.hidden{display:none}@media(max-width:1100px) and (min-width:901px){.app{grid-template-columns:200px minmax(0,1fr) 280px}.toolbar{height:auto}.toolbar select{min-width:160px}}@media(max-width:900px){body{height:auto;min-height:100vh;overflow:auto}.app{grid-template-columns:1fr;grid-template-rows:220px minmax(560px,72vh) auto;height:auto;min-height:100vh}.sidebar{border-right:0;border-bottom:1px solid var(--line)}.workspace{grid-template-rows:auto minmax(0,1fr);min-height:560px}.toolbar select{width:100%;min-width:0}.status{margin-left:0}.canvas-wrap{min-height:460px}.canvas-wrap canvas{max-height:calc(72vh - 130px)}.inspector{border-left:0;border-top:1px solid var(--line);padding:14px}.row{flex-wrap:wrap}.row>*{min-width:140px}}
</style>
</head>
<body>
<div class="app">
  <aside class="sidebar"><div class="brand">ATLAS LF-1</div><div id="sources"></div></aside>
  <main class="workspace">
    <div class="toolbar">
      <select id="profile"></select>
      <button id="newBox" title="Draw a residue or negative-space formation">Draw formation</button>
      <button id="deleteBox" class="danger" title="Delete the selected physical annotation">Delete box</button>
      <span id="candidateCount"></span>
      <span class="legend"><i class="swatch annotation"></i>Physical annotation</span>
      <span class="legend"><i class="swatch candidate"></i>Algorithm candidate</span>
      <span id="saveStatus" class="status"></span>
      <button id="save" class="primary">Save</button>
    </div>
    <div class="canvas-wrap"><canvas id="canvas"></canvas></div>
  </main>
  <aside class="inspector">
    <h2>Physical annotation</h2>
    <div id="noSelection" class="empty">No physical annotation selected.</div>
    <div id="form" class="hidden">
      <div class="field"><label>Annotation ID</label><input id="annotationId" readonly></div>
      <div class="row">
        <div class="field"><label>Physical type</label><select id="polarity"><option value="residue">Residue</option><option value="negativeSpace">Negative space</option><option value="mixed">Mixed</option></select></div>
        <div class="field"><label>Review decision</label><select id="reviewStatus"><option value="include">Include</option><option value="uncertain">Uncertain</option><option value="exclude">Exclude</option></select></div>
      </div>
      <div class="field"><label>Formation group ID</label><input id="formationGroupId" placeholder="optional"></div>
      <div class="field"><label>Physical notes</label><textarea id="notes"></textarea></div>
      <h3>Candidate alignment</h3>
      <div id="candidates"></div>
    </div>
    <h3>Evaluation</h3><div id="evaluation" class="summary"></div>
  </aside>
</div>
<script>
'use strict';
let state,sourceIndex=0,profileId,selectedId=null,drawing=false,start=null,image=new Image();
const $=id=>document.getElementById(id),canvas=$('canvas'),ctx=canvas.getContext('2d');
const profileLabels={
  'p00-pass-through':'p00 | Current default',
  'p01-outgoing-1':'p01 | One outgoing edge',
  'p02-outgoing-2':'p02 | Two outgoing edges',
  'p03-touch-only-outgoing-2':'p03 | Touching boxes only',
  'p04-zero-gap-outgoing-2':'p04 | Zero gap',
  'p05-gap-2px-outgoing-2':'p05 | Two-pixel gap',
  'p06-gap-4px-outgoing-2':'p06 | Four-pixel gap',
  'p07-gap-8px-outgoing-2':'p07 | Eight-pixel gap'
};
fetch('/api/state').then(r=>r.json()).then(data=>{state=data;profileId=state.profiles[0];init();});
function init(){
  $('profile').innerHTML=state.profiles.map(p=>`<option value="${p}">${profileLabels[p]??p}</option>`).join('');
  $('profile').value=profileId;$('profile').onchange=e=>{profileId=e.target.value;render();};
  $('newBox').onclick=()=>{drawing=true;$('newBox').classList.add('active');};
  $('deleteBox').onclick=deleteSelected;$('save').onclick=save;
  ['polarity','reviewStatus','formationGroupId','notes'].forEach(id=>$(id).oninput=updateForm);
  canvas.onpointerdown=pointerDown;canvas.onpointermove=pointerMove;canvas.onpointerup=pointerUp;
  $('saveStatus').textContent='Saved';
  renderSources();loadImage();
}
function currentImage(){return state.images[sourceIndex];}
function observation(){return state.observations.find(o=>o.sourceId===currentImage().sourceId&&o.profileId===profileId);}
function annotations(){return state.annotations.filter(a=>a.sourceId===currentImage().sourceId);}
function selected(){return state.annotations.find(a=>a.annotationId===selectedId);}
function renderSources(){$('sources').innerHTML=state.images.map((im,i)=>`<button class="source ${i===sourceIndex?'active':''}" data-i="${i}">${im.sourceId}<small>${im.surfaceType} / ${im.captureGroupId}</small></button>`).join('');document.querySelectorAll('.source').forEach(b=>b.onclick=()=>{sourceIndex=Number(b.dataset.i);selectedId=null;renderSources();loadImage();});}
function loadImage(){image.onload=()=>{canvas.width=image.naturalWidth;canvas.height=image.naturalHeight;render();};image.src=currentImage().imageUrl+'?v='+Date.now();}
function render(){if(!state)return;ctx.clearRect(0,0,canvas.width,canvas.height);ctx.drawImage(image,0,0,canvas.width,canvas.height);const obs=observation();$('candidateCount').textContent=`${obs.candidates.length} candidates`;ctx.lineWidth=Math.max(2,canvas.width/500);for(const c of obs.candidates)box(candidateInSource(c),'#63b3ff',`C${c.candidateId}`);for(const a of annotations())box(a,a.annotationId===selectedId?'#ff6b64':'#ffcf5b',a.annotationId);renderForm();renderEvaluation();}
function candidateInSource(v){const width=image.naturalWidth,height=image.naturalHeight,clamp=n=>Math.max(0,Math.min(1,n));if(width===height)return v;if(width<height){const contentWidth=width/height,padding=(1-contentWidth)/2;return{...v,left:clamp((v.left-padding)/contentWidth),right:clamp((v.right-padding)/contentWidth)};}const contentHeight=height/width,padding=(1-contentHeight)/2;return{...v,top:clamp((v.top-padding)/contentHeight),bottom:clamp((v.bottom-padding)/contentHeight)};}
function box(v,color,label){const x=v.left*canvas.width,y=v.top*canvas.height,w=(v.right-v.left)*canvas.width,h=(v.bottom-v.top)*canvas.height;ctx.strokeStyle=color;ctx.strokeRect(x,y,w,h);ctx.fillStyle=color;ctx.font=`${Math.max(12,canvas.width/70)}px Arial`;ctx.fillText(label,x+3,y+16);}
function pointer(e){const r=canvas.getBoundingClientRect();return{x:Math.max(0,Math.min(1,(e.clientX-r.left)/r.width)),y:Math.max(0,Math.min(1,(e.clientY-r.top)/r.height))};}
function pointerDown(e){if(drawing){start=pointer(e);canvas.setPointerCapture(e.pointerId);return;}const p=pointer(e);const hit=annotations().slice().reverse().find(a=>p.x>=a.left&&p.x<=a.right&&p.y>=a.top&&p.y<=a.bottom);selectedId=hit?.annotationId??null;render();}
function pointerMove(e){if(!drawing||!start)return;render();const p=pointer(e);ctx.strokeStyle='#ffcf5b';ctx.strokeRect(Math.min(start.x,p.x)*canvas.width,Math.min(start.y,p.y)*canvas.height,Math.abs(p.x-start.x)*canvas.width,Math.abs(p.y-start.y)*canvas.height);}
function pointerUp(e){if(!drawing||!start)return;const p=pointer(e),left=Math.min(start.x,p.x),top=Math.min(start.y,p.y),right=Math.max(start.x,p.x),bottom=Math.max(start.y,p.y);drawing=false;start=null;$('newBox').classList.remove('active');if(right-left<.005||bottom-top<.005){render();return;}const id=nextId(),alignments=[];for(const pid of state.profiles){const o=state.observations.find(v=>v.sourceId===currentImage().sourceId&&v.profileId===pid);for(const c of o.candidates)alignments.push({profileId:pid,candidateId:c.candidateId,status:'unrelated'});}state.annotations.push({annotationId:id,sourceId:currentImage().sourceId,left,top,right,bottom,polarity:'residue',reviewStatus:'include',formationGroupId:null,notes:'',alignments});selectedId=id;markDirty();render();}
function nextId(){let i=1,id;do{id=`lf1-ann-${String(i++).padStart(3,'0')}`;}while(state.annotations.some(a=>a.annotationId===id));return id;}
function renderForm(){const a=selected();$('noSelection').classList.toggle('hidden',!!a);$('form').classList.toggle('hidden',!a);if(!a)return;$('annotationId').value=a.annotationId;$('polarity').value=a.polarity;$('reviewStatus').value=a.reviewStatus;$('formationGroupId').value=a.formationGroupId??'';$('notes').value=a.notes;const obs=observation();$('candidates').innerHTML=obs.candidates.map(c=>{const al=a.alignments.find(v=>v.profileId===profileId&&v.candidateId===c.candidateId);return `<div class="candidate"><div class="candidate-head"><b>C${c.candidateId}</b><span>${c.nodeCount} nodes</span></div><select data-candidate="${c.candidateId}"><option value="unrelated">Unrelated</option><option value="partial">Partial overlap</option><option value="aligned">Aligned</option></select></div>`;}).join('')||'<div class="empty">No candidates.</div>';document.querySelectorAll('#candidates select').forEach(s=>{const al=a.alignments.find(v=>v.profileId===profileId&&v.candidateId===Number(s.dataset.candidate));s.value=al?.status??'unrelated';s.onchange=()=>{al.status=s.value;markDirty();};});}
function updateForm(){const a=selected();if(!a)return;a.polarity=$('polarity').value;a.reviewStatus=$('reviewStatus').value;a.formationGroupId=$('formationGroupId').value||null;a.notes=$('notes').value;markDirty();}
function deleteSelected(){if(!selectedId)return;state.annotations=state.annotations.filter(a=>a.annotationId!==selectedId);selectedId=null;markDirty();render();}
function markDirty(){$('saveStatus').textContent='Unsaved changes';$('saveStatus').classList.add('dirty');}
function renderEvaluation(){const e=state.evaluation;$('evaluation').textContent=`${e.includedAnnotationCount} included / residue ${e.residueAnnotationCount} / negative ${e.negativeSpaceAnnotationCount} / candidate ${e.productionProfileCandidateId??'none'}`;}
async function save(){updateForm();$('saveStatus').textContent='Saving';const response=await fetch('/api/annotations',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({schemaVersion:'1.0',researchId:state.researchId,annotations:state.annotations})});const result=await response.json();if(!response.ok){$('saveStatus').textContent=result.error??'Failed';return;}state.evaluation=result.evaluation;$('saveStatus').textContent='Saved';$('saveStatus').classList.remove('dirty');renderEvaluation();}
</script>
</body>
</html>
''';
