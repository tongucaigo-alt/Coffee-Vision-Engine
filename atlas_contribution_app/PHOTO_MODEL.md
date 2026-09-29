# Yerel fotoğraf kontrolü modeli

- Model: Google MediaPipe EfficientNet-Lite0, float32, sürüm 1.
- Yerel dosya: `android/app/src/main/assets/efficientnet_lite0.tflite`.
- SHA-256: `6c7ab0a6e5dcbf38a8c33b960996a55a3b4300b36a018c4545801de3a3c8bde0`.
- Kaynak: https://storage.googleapis.com/mediapipe-models/image_classifier/efficientnet_lite0/float32/1/efficientnet_lite0.tflite
- Resmî model açıklaması: https://developers.google.com/edge/mediapipe/solutions/vision/image_classifier#models
- Android kitaplığı: `com.google.mediapipe:tasks-vision:0.10.21`.

Model genel ImageNet sınıflarını tanır; telveye özel eğitim veya sembol tanıma değildir. Model uygulamayla birlikte gelir, fotoğraflar sınıflandırma için ağ üzerinden gönderilmez. İki görünümün ilk üç sınıfı kullanılır. Mevcut yayın eşiği doğrulanmadığından kesin engelleme kapalıdır; belirsizlik/uygunsuzluk uyarısından kullanıcı devam edebilir.

Bellek sahipliği: MPImage kapatılırken bağlı Bitmap geri dönüştürülür. Tam görüntü ve kırpma aynı bitmap olabileceği için her çıkarım kendi kopyasına sahip olur. Kaynak: https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/java/com/google/mediapipe/framework/image/BitmapImageContainer.java
