import 'dart:convert';
import 'dart:io';

import 'src/k6a_dataset.dart';
import 'src/lf2_review.dart';

Future<void> main(List<String> arguments) async {
  final options = Lf2ReviewServerOptions.parse(arguments);
  final application = await Lf2ReviewApplication.load(options);
  final server = await HttpServer.bind(options.host, options.port);
  stdout.writeln('LF-2 review: http://${options.host}:${server.port}/');
  await for (final request in server) {
    await application.handle(request);
  }
}

final class Lf2ReviewServerOptions {
  const Lf2ReviewServerOptions({
    required this.datasetRoot,
    required this.manifestPath,
    required this.freezePath,
    required this.observationsPath,
    required this.groundTruthPath,
    required this.outputDirectory,
    required this.repositoryRoot,
    required this.host,
    required this.port,
  });

  factory Lf2ReviewServerOptions.parse(List<String> arguments) {
    const flags = {
      '--dataset',
      '--manifest',
      '--freeze',
      '--observations',
      '--ground-truth',
      '--output',
      '--repository-root',
      '--host',
      '--port',
    };
    if (arguments.length.isOdd) {
      throw const FormatException('LF-2 review flags require values.');
    }
    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index += 2) {
      final flag = arguments[index];
      if (!flags.contains(flag)) {
        throw FormatException('Unknown LF-2 review flag: $flag.');
      }
      if (values.containsKey(flag)) {
        throw FormatException('Duplicate LF-2 review flag: $flag.');
      }
      final value = arguments[index + 1];
      if (value.isEmpty) {
        throw FormatException('Missing LF-2 review value: $flag.');
      }
      values[flag] = value;
    }
    for (final flag in const {
      '--dataset',
      '--manifest',
      '--freeze',
      '--observations',
      '--ground-truth',
      '--output',
      '--repository-root',
    }) {
      if (!values.containsKey(flag)) {
        throw FormatException('Missing LF-2 review flag: $flag.');
      }
    }
    final host = values['--host'] ?? '127.0.0.1';
    if (host != '127.0.0.1' && host != 'localhost') {
      throw const FormatException('LF-2 review host must be loopback.');
    }
    final port = values.containsKey('--port')
        ? int.tryParse(values['--port']!)
        : 8767;
    if (port == null || port <= 0 || port > 65535) {
      throw const FormatException('LF-2 review port is invalid.');
    }
    return Lf2ReviewServerOptions(
      datasetRoot: values['--dataset']!,
      manifestPath: values['--manifest']!,
      freezePath: values['--freeze']!,
      observationsPath: values['--observations']!,
      groundTruthPath: values['--ground-truth']!,
      outputDirectory: values['--output']!,
      repositoryRoot: values['--repository-root']!,
      host: host,
      port: port,
    );
  }

  final String datasetRoot;
  final String manifestPath;
  final String freezePath;
  final String observationsPath;
  final String groundTruthPath;
  final String outputDirectory;
  final String repositoryRoot;
  final String host;
  final int port;
}

final class Lf2ReviewImage {
  const Lf2ReviewImage({
    required this.sourceId,
    required this.surfaceType,
    required this.format,
    required this.path,
  });

  final String sourceId;
  final String surfaceType;
  final String format;
  final String path;
}

final class Lf2ReviewApplication {
  Lf2ReviewApplication({
    required this.options,
    required this.observations,
    required this.groundTruth,
    required Iterable<Lf2ReviewImage> images,
    required Lf2AlignmentReview review,
  }) : images = List<Lf2ReviewImage>.unmodifiable(images),
       _review = review,
       _reviewCompleted = false;

  static Future<Lf2ReviewApplication> load(
    Lf2ReviewServerOptions options,
  ) async {
    final dataset = await const K6aDatasetPreflight().validate(
      datasetRoot: options.datasetRoot,
      manifestPath: options.manifestPath,
      freezePath: options.freezePath,
    );
    final observations = Lf2ObservationIndex.parse(
      await File(options.observationsPath).readAsString(),
    );
    final groundTruth = const Lf2GroundTruthCodec().parse(
      source: await File(options.groundTruthPath).readAsString(),
      observations: observations,
    );
    final groundTruthSources = groundTruth.annotations
        .map((value) => value.sourceId)
        .toSet();
    final images = <Lf2ReviewImage>[];
    for (final entry in dataset.entries) {
      if (!groundTruthSources.contains(entry.sourceId)) continue;
      images.add(
        Lf2ReviewImage(
          sourceId: entry.sourceId,
          surfaceType: entry.surfaceType.name,
          format: entry.format,
          path: _resolveDatasetPath(options.datasetRoot, entry.relativePath),
        ),
      );
    }
    images.sort((first, second) => first.sourceId.compareTo(second.sourceId));
    if (images.length != groundTruthSources.length) {
      throw const FormatException('LF-2 review images are incomplete.');
    }

    final reviewFile = File(
      _join(options.outputDirectory, 'candidate_alignment_review.json'),
    );
    final codec = const Lf2AlignmentCodec();
    final reviewExists = reviewFile.existsSync();
    final review = reviewExists
        ? codec.parse(
            source: await reviewFile.readAsString(),
            observations: observations,
            groundTruth: groundTruth,
          )
        : codec.createDefault(
            observations: observations,
            groundTruth: groundTruth,
          );
    final application = Lf2ReviewApplication(
      options: options,
      observations: observations,
      groundTruth: groundTruth,
      images: images,
      review: review,
    );
    application._reviewCompleted = reviewExists;
    return application;
  }

  final Lf2ReviewServerOptions options;
  final Lf2ObservationIndex observations;
  final Lf2GroundTruthSet groundTruth;
  final List<Lf2ReviewImage> images;
  Lf2AlignmentReview _review;
  bool _reviewCompleted;

  Future<void> handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/') {
        request.response.headers.contentType = ContentType.html;
        request.response.write(_html);
        return request.response.close();
      }
      if (request.method == 'GET' && path == '/api/state') {
        return _json(request.response, _state());
      }
      if (request.method == 'GET' && path.startsWith('/image/')) {
        return _image(
          request.response,
          Uri.decodeComponent(path.substring('/image/'.length)),
        );
      }
      if (request.method == 'POST' && path == '/api/review') {
        final source = await utf8.decoder.bind(request).join();
        final review = const Lf2AlignmentCodec().parse(
          source: source,
          observations: observations,
          groundTruth: groundTruth,
        );
        final evaluation = const Lf2Evaluator().evaluate(
          observations: observations,
          groundTruth: groundTruth,
          review: review,
        );
        await const Lf2ReviewWriter().write(
          outputDirectory: options.outputDirectory,
          repositoryRoot: options.repositoryRoot,
          review: review,
          evaluation: evaluation,
        );
        _review = review;
        _reviewCompleted = true;
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
        'error': 'LF-2 research file operation failed.',
      });
    } on Object {
      request.response.statusCode = HttpStatus.internalServerError;
      return _json(request.response, {'error': 'LF-2 review request failed.'});
    }
  }

  Map<String, Object?> _state() {
    final evaluation = const Lf2Evaluator().evaluate(
      observations: observations,
      groundTruth: groundTruth,
      review: _review,
      alignmentReviewCompleted: _reviewCompleted,
    );
    return {
      'researchId': observations.researchId,
      'sourceGroundTruthResearchId': groundTruth.sourceResearchId,
      'profiles': observations.profileIds,
      'images': [
        for (final image in images)
          {
            'sourceId': image.sourceId,
            'surfaceType': image.surfaceType,
            'imageUrl': '/image/${Uri.encodeComponent(image.sourceId)}',
          },
      ],
      'annotations': groundTruth.annotations
          .map((value) => value.toJson())
          .toList(growable: false),
      'observations': [
        for (final image in images)
          for (final profileId in observations.profileIds)
            _observationJson(
              observations.observation(profileId, image.sourceId),
            ),
      ],
      'alignments': _review.alignments
          .map((value) => value.toJson())
          .toList(growable: false),
      'evaluation': evaluation.toJson(),
    };
  }

  Map<String, Object?> _observationJson(Lf2ReviewObservation observation) {
    final contentRect = observation.contentRect;
    return {
      'sourceId': observation.sourceId,
      'profileId': observation.profileId,
      'analysisStatus': observation.analysisStatus,
      'determinismStatus': observation.determinismStatus,
      'residuePixelsConserved': observation.residuePixelsConserved,
      'candidates': contentRect == null
          ? <Object>[]
          : observation.candidates
                .map((value) => value.toJson(contentRect: contentRect))
                .toList(growable: false),
    };
  }

  Future<void> _image(HttpResponse response, String sourceId) async {
    final matches = images.where((value) => value.sourceId == sourceId);
    if (matches.isEmpty) {
      response.statusCode = HttpStatus.notFound;
      return _json(response, {'error': 'Unknown image.'});
    }
    final image = matches.single;
    response.headers.contentType = image.format == 'png'
        ? ContentType('image', 'png')
        : ContentType('image', 'jpeg');
    await response.addStream(File(image.path).openRead());
    await response.close();
  }
}

Future<void> _json(HttpResponse response, Object value) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(value));
  return response.close();
}

String _resolveDatasetPath(String root, String relativePath) {
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

String _join(String directory, String filename) =>
    [directory, filename].join(Platform.pathSeparator);

const String _html = r'''
<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Atlas Local Formation Review</title><style>
:root{color-scheme:dark;--bg:#10171b;--panel:#172126;--line:#34454d;--text:#edf3f4;--muted:#9fb0b7;--accent:#1f9d98;--residue:#ff9f1c;--negative:#35c8ff;--truth:#ff4fd8}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px Arial,sans-serif}.app{display:grid;grid-template-columns:230px minmax(0,1fr) 350px;height:100vh}.sidebar,.inspector{background:var(--panel);overflow:auto}.sidebar{border-right:1px solid var(--line)}.inspector{border-left:1px solid var(--line);padding:14px}.brand{padding:14px;font-weight:700;border-bottom:1px solid var(--line)}.source{display:block;width:100%;padding:10px 12px;text-align:left;border:0;border-bottom:1px solid #27363c;border-radius:0;background:transparent;color:var(--text)}.source.active{background:#20343a}.source small{display:block;color:var(--muted);margin-top:3px}.workspace{display:grid;grid-template-rows:auto minmax(0,1fr);min-width:0}.toolbar{display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:9px 12px;background:#1b282e;border-bottom:1px solid var(--line)}select,button{font:inherit;color:inherit;background:#10191d;border:1px solid var(--line);border-radius:4px;padding:7px}.toolbar select{min-width:220px}.canvas-wrap{display:grid;place-items:center;overflow:auto;padding:14px}canvas{max-width:100%;max-height:calc(100vh - 90px);background:#090d0f;box-shadow:0 0 0 1px var(--line);cursor:crosshair}h2{font-size:16px;margin:0 0 10px}.notice{padding:9px;border:1px solid #735e2b;color:#ffe6a3;background:#2a2416;margin-bottom:8px}.legend{display:flex;flex-wrap:wrap;gap:8px 12px;margin:0 0 12px;color:var(--muted);font-size:12px}.legend span{display:flex;align-items:center;gap:5px}.swatch{width:18px;height:4px;border-radius:2px;background:currentColor}.swatch.truth{color:var(--truth);background:repeating-linear-gradient(90deg,var(--truth) 0 6px,transparent 6px 9px)}.swatch.residue{color:var(--residue)}.swatch.negative{color:var(--negative)}.candidate{--candidate-color:var(--line);position:relative;padding:10px 10px 10px 13px;margin:0 -6px;border-top:1px solid var(--line);border-left:3px solid transparent;cursor:pointer;transition:background .12s,border-color .12s,box-shadow .12s}.candidate:hover,.candidate.hovered{background:#203038;border-left-color:var(--candidate-color)}.candidate.selected{background:#263a42;border-left-color:var(--candidate-color);box-shadow:inset 0 0 0 1px var(--candidate-color)}.candidate:focus-visible{outline:2px solid var(--candidate-color);outline-offset:-2px}.candidate-head{display:flex;justify-content:space-between;gap:8px}.candidate-head b{color:var(--candidate-color)}.candidate small{display:block;color:var(--muted);margin:4px 0 7px;overflow-wrap:anywhere}.candidate select{width:100%}.save{width:100%;margin-top:12px;background:var(--accent);border-color:var(--accent);font-weight:700}.summary{color:var(--muted);font-size:12px;margin:8px 0}.status{color:var(--muted);margin-left:auto}.dirty{color:#ffc95f}@media(max-width:900px){.app{grid-template-columns:1fr;grid-template-rows:190px 60vh auto;height:auto}.sidebar{border-right:0}.inspector{border-left:0;border-top:1px solid var(--line)}.toolbar select{width:100%}}
</style></head><body><div class="app"><aside class="sidebar"><div class="brand">Atlas Local Formation Review</div><div id="sources"></div></aside><main class="workspace"><div class="toolbar"><select id="annotation"></select><select id="profile"></select><span id="status" class="status">Yükleniyor</span></div><div class="canvas-wrap"><canvas id="canvas"></canvas></div></main><aside class="inspector"><h2>Fiziksel hizalama</h2><div class="notice">Adaylar yalnız geometrik yakınlığa göre sıralanır. Sistem hiçbir adayı otomatik kabul etmez.</div><div class="legend"><span><i class="swatch truth"></i>Annotation</span><span><i class="swatch residue"></i>Residue candidate</span><span><i class="swatch negative"></i>Negative candidate</span></div><div id="truth" class="summary"></div><div id="candidates"></div><button class="save" id="save">Kaydet ve değerlendir</button><div id="evaluation" class="summary"></div></aside></div><script>
const $=id=>document.getElementById(id);let state,imageIndex=0,profileId,annotationId,dirty=false,selectedCandidateId=null,hoveredCandidateId=null;const canvas=$('canvas'),ctx=canvas.getContext('2d'),image=new Image();
async function boot(){state=await(await fetch('/api/state')).json();profileId=state.profiles[0];annotationId=annotationsForImage()[0]?.annotationId;renderSources();renderSelects();loadImage();renderEvaluation();$('save').onclick=save;canvas.addEventListener('mousemove',event=>setHoveredCandidate(candidateAtCanvasPoint(event)?.candidateId??null));canvas.addEventListener('mouseleave',()=>setHoveredCandidate(null));canvas.addEventListener('click',event=>{const candidate=candidateAtCanvasPoint(event);if(candidate)selectCandidate(candidate.candidateId,true)});}
function currentImage(){return state.images[imageIndex]}function annotationsForImage(){return state.annotations.filter(a=>a.sourceId===currentImage().sourceId)}function annotation(){return state.annotations.find(a=>a.annotationId===annotationId)}function observation(){return state.observations.find(o=>o.sourceId===currentImage().sourceId&&o.profileId===profileId)}
function resetCandidateFocus(){selectedCandidateId=null;hoveredCandidateId=null}
function renderSources(){$('sources').innerHTML=state.images.map((v,i)=>`<button class="source ${i===imageIndex?'active':''}" data-i="${i}">${v.sourceId}<small>${v.surfaceType}</small></button>`).join('');document.querySelectorAll('.source').forEach(b=>b.onclick=()=>{imageIndex=Number(b.dataset.i);annotationId=annotationsForImage()[0]?.annotationId;resetCandidateFocus();renderSources();renderSelects();loadImage();});}
function renderSelects(){$('annotation').innerHTML=annotationsForImage().map(a=>`<option value="${a.annotationId}">${a.annotationId} / ${a.polarity}</option>`).join('');$('annotation').value=annotationId;$('annotation').onchange=()=>{annotationId=$('annotation').value;resetCandidateFocus();render()};$('profile').innerHTML=state.profiles.map(p=>`<option value="${p}">${p}</option>`).join('');$('profile').value=profileId;$('profile').onchange=()=>{profileId=$('profile').value;resetCandidateFocus();render()};}
function loadImage(){image.onload=()=>{canvas.width=image.naturalWidth;canvas.height=image.naturalHeight;render()};image.src=currentImage().imageUrl+'?v='+Date.now()}
function render(){const a=annotation(),o=observation();if(!a||!o){renderCanvas();$('candidates').innerHTML='<div class="summary">Bu profilde aday yok.</div>';return}const ids=new Set(o.candidates.map(c=>c.candidateId));if(!ids.has(selectedCandidateId))selectedCandidateId=null;if(!ids.has(hoveredCandidateId))hoveredCandidateId=null;renderCanvas();$('truth').textContent=`${a.polarity} / ${a.reviewStatus} / ${a.formationGroupId??'no group'}`;const candidates=o.candidates.map(c=>({...c,overlap:iou(a,c)})).sort((x,y)=>y.overlap-x.overlap||x.candidateId-y.candidateId);$('candidates').innerHTML=candidates.map(c=>{const al=state.alignments.find(v=>v.annotationId===a.annotationId&&v.profileId===profileId&&v.candidateId===c.candidateId),color=c.polarity==='residue'?'var(--residue)':'var(--negative)';return `<div class="candidate" tabindex="0" role="button" aria-pressed="false" data-candidate-id="${c.candidateId}" style="--candidate-color:${color}"><div class="candidate-head"><b>${c.polarity==='residue'?'Residue':'Negative'} C${c.candidateId}</b><span>${(c.overlap*100).toFixed(1)}%</span></div><small>${c.pixelCount} px / support ${c.supportIdentity}</small><select data-id="${c.candidateId}" aria-label="C${c.candidateId} hizalama"><option value="unrelated">Unrelated</option><option value="partial">Partial</option><option value="aligned">Aligned</option></select></div>`}).join('')||'<div class="summary">Bu profilde aday yok.</div>';document.querySelectorAll('.candidate').forEach(row=>{const id=Number(row.dataset.candidateId);row.onmouseenter=()=>setHoveredCandidate(id);row.onmouseleave=()=>setHoveredCandidate(null);row.onclick=()=>selectCandidate(id,false);row.onkeydown=event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();selectCandidate(id,false)}}});document.querySelectorAll('#candidates select').forEach(s=>{const al=state.alignments.find(v=>v.annotationId===a.annotationId&&v.profileId===profileId&&v.candidateId===Number(s.dataset.id));s.value=al.status;s.onchange=()=>{al.status=s.value;dirty=true;$('status').textContent='Kaydedilmedi';$('status').classList.add('dirty')}});syncCandidateHighlights()}
function renderCanvas(){ctx.clearRect(0,0,canvas.width,canvas.height);if(image.complete&&image.naturalWidth)ctx.drawImage(image,0,0,canvas.width,canvas.height);const a=annotation(),o=observation();if(!a||!o)return;for(const c of o.candidates)drawCandidate(c,'normal');drawBox(a,{color:'#ff4fd8',label:`ANN ${a.annotationId}`,lineWidth:Math.max(3,canvas.width/420),dashed:true});const selected=o.candidates.find(c=>c.candidateId===selectedCandidateId);if(selected)drawCandidate(selected,'selected');const hovered=o.candidates.find(c=>c.candidateId===hoveredCandidateId);if(hovered&&hovered.candidateId!==selectedCandidateId)drawCandidate(hovered,'hovered')}
function drawCandidate(candidate,mode){const color=candidate.polarity==='residue'?'#ff9f1c':'#35c8ff',lineWidth=mode==='selected'?Math.max(7,canvas.width/190):mode==='hovered'?Math.max(5,canvas.width/250):Math.max(2,canvas.width/520);drawBox(candidate,{color,label:`C${candidate.candidateId} ${candidate.polarity==='residue'?'R':'N'}`,lineWidth,dashed:false,emphasized:mode!=='normal'})}
function drawBox(v,{color,label,lineWidth,dashed,emphasized=false}){const x=v.left*canvas.width,y=v.top*canvas.height,w=(v.right-v.left)*canvas.width,h=(v.bottom-v.top)*canvas.height,fontSize=Math.max(16,Math.min(30,canvas.width/55)),padding=Math.max(4,canvas.width/500);ctx.save();ctx.setLineDash(dashed?[Math.max(10,canvas.width/120),Math.max(6,canvas.width/180)]:[]);ctx.lineWidth=lineWidth;ctx.strokeStyle=color;if(emphasized){ctx.shadowColor=color;ctx.shadowBlur=Math.max(10,canvas.width/110)}ctx.strokeRect(x,y,w,h);ctx.setLineDash([]);ctx.shadowBlur=0;ctx.font=`700 ${fontSize}px Arial`;const labelWidth=ctx.measureText(label).width+padding*2,labelHeight=fontSize+padding*2,labelX=Math.max(0,Math.min(x,canvas.width-labelWidth)),labelY=y-labelHeight>=0?y-labelHeight:Math.min(y+lineWidth,canvas.height-labelHeight);ctx.fillStyle=emphasized?color:'rgba(8,13,15,.92)';ctx.fillRect(labelX,labelY,labelWidth,labelHeight);ctx.strokeStyle=color;ctx.lineWidth=Math.max(2,lineWidth/2);ctx.strokeRect(labelX,labelY,labelWidth,labelHeight);ctx.fillStyle=emphasized?'#071013':'#ffffff';ctx.fillText(label,labelX+padding,labelY+fontSize+padding/2);ctx.restore()}
function candidateAtCanvasPoint(event){const o=observation();if(!o)return null;const rect=canvas.getBoundingClientRect(),x=(event.clientX-rect.left)/rect.width,y=(event.clientY-rect.top)/rect.height;return o.candidates.filter(c=>x>=c.left&&x<=c.right&&y>=c.top&&y<=c.bottom).sort((a,b)=>candidateArea(a)-candidateArea(b)||a.candidateId-b.candidateId)[0]??null}
function candidateArea(candidate){return(candidate.right-candidate.left)*(candidate.bottom-candidate.top)}
function setHoveredCandidate(candidateId){if(hoveredCandidateId===candidateId)return;hoveredCandidateId=candidateId;renderCanvas();syncCandidateHighlights()}
function selectCandidate(candidateId,scroll){selectedCandidateId=candidateId;renderCanvas();syncCandidateHighlights();if(scroll){const row=document.querySelector(`.candidate[data-candidate-id="${candidateId}"]`);row?.scrollIntoView({behavior:'smooth',block:'center'})}}
function syncCandidateHighlights(){document.querySelectorAll('.candidate').forEach(row=>{const id=Number(row.dataset.candidateId),selected=id===selectedCandidateId;row.classList.toggle('selected',selected);row.classList.toggle('hovered',id===hoveredCandidateId);row.setAttribute('aria-pressed',String(selected))})}
function iou(a,b){const l=Math.max(a.left,b.left),t=Math.max(a.top,b.top),r=Math.min(a.right,b.right),bt=Math.min(a.bottom,b.bottom),inter=Math.max(0,r-l)*Math.max(0,bt-t),union=(a.right-a.left)*(a.bottom-a.top)+(b.right-b.left)*(b.bottom-b.top)-inter;return union?inter/union:0}
async function save(){const body={schemaVersion:'1.0',researchId:state.researchId,sourceGroundTruthResearchId:state.sourceGroundTruthResearchId,alignments:state.alignments};$('status').textContent='Kaydediliyor';const response=await fetch('/api/review',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)}),result=await response.json();if(!response.ok){$('status').textContent=result.error??'Hata';return}dirty=false;$('status').textContent='Kaydedildi';$('status').classList.remove('dirty');state.evaluation=result.evaluation;renderEvaluation()}
function renderEvaluation(){const e=state.evaluation;$('evaluation').textContent=`Primary ${e.includedPrimaryAnnotationCount} / residue ${e.residueAnnotationCount} / negative ${e.negativeSpaceAnnotationCount} / candidate ${e.productionProfileCandidateId??'none'}`}
boot();
</script></body></html>
''';
