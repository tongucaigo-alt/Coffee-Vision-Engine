# Protobuf Lite reads generated fields reflectively. Preserve those fields in
# minified builds used by MediaPipe; do not disable shrinking for the whole app.
# https://github.com/protocolbuffers/protobuf/blob/main/java/lite/proguard.pgcfg
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}

# The logger discovers its caller from the live stack; inlining this factory
# removes the frame it searches for (Graph initialization then fails).
-keep class com.google.common.flogger.** { *; }

# MediaPipe's native runtime calls framework methods not visible to R8.
# https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/java/com/google/mediapipe/framework/proguard.pgcfg
-keep public interface com.google.mediapipe.framework.* { public *; }
-keep class com.google.mediapipe.framework.Packet {
    public static *** create(***);
    public long getNativeHandle();
    public void release();
}
-keepclassmembers class com.google.mediapipe.framework.PacketCreator {
    *** releaseWithSyncToken(...);
}
-keep class com.google.mediapipe.framework.MediaPipeException {
    <init>(int, byte[]);
}
-keep class com.google.mediapipe.framework.ProtoUtil$SerializedMessage { *; }
