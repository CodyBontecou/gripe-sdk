export interface Bindings {
  GRIPE_IMAGES: R2Bucket;
  GRIPE_API_KEY: string;
  GITHUB_TOKEN: string;
  GITHUB_REPO?: string;
  R2_PUBLIC_BASE: string;
}

export interface GripeMetadata {
  appVersion: string;
  build: string;
  bundleIdentifier: string;
  osName: string;
  osVersion: string;
  deviceModel: string;
  screenWidth: number;
  screenHeight: number;
  capturedAt: string;
  viewControllerName?: string;
  locale: string;
}
