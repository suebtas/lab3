{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Serve CanvasKit from the build's local canvaskit/ directory instead of
    // the Google CDN, so the strict self-only CSP (connect-src 'self') holds
    // and the image stays fully self-contained/portable.
    canvasKitBaseUrl: "canvaskit/"
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});