{{flutter_js}}
{{flutter_build_config}}

// Flutter emits main.dart.js with a stable file name. Pair it with the
// generated service-worker revision so a new deployment cannot reuse a
// browser's previously cached application bundle.
const khairBuildRevision = {{flutter_service_worker_version}};
_flutter.buildConfig.builds = _flutter.buildConfig.builds.map((build) => ({
  ...build,
  mainJsPath: build.mainJsPath
      ? `${build.mainJsPath}?v=${khairBuildRevision}`
      : `main.dart.js?v=${khairBuildRevision}`,
}));

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: khairBuildRevision,
  },
});
