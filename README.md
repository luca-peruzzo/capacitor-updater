# Capacitor updater
  <a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>
Update Ionic Capacitor apps without App/Play Store review (Code-push / hot-code updates).

You have 3 ways possible :
- Use [capgo.app](https://capgo.app) a full featured auto update system in 5 min Setup, to manage version, update, revert and see stats.
- Use your own server update with auto update system
- Use manual methods to zip, upload, download, from JS to do it when you want.


## Community
Join the [discord](https://discord.gg/VnYRvBfgA6) to get help.

## Documentation
I maintain a more user friendly and complete [documentation here](https://docs.capgo.app/).

## Installation

```bash
npm install @capgo/capacitor-updater
npx cap sync
```

## Auto-update setup

Create account in [capgo.app](https://capgo.app) and get your [API key](https://capgo.app/app/apikeys)
- Login to CLI `npx @capgo/cli@latest  login API_KEY`
- Add app with CLI `npx @capgo/cli@latest add`
- Upload app to channel production `npx @capgo/cli@latest  upload -c production`
- Set channel production public `npx @capgo/cli@latest  set -c production -s public`
- Add to your main code
```javascript
  import { CapacitorUpdater } from '@capgo/capacitor-updater'
  CapacitorUpdater.notifyAppReady()
```
This tells Capacitor Updator that the current update bundle has loaded succesfully. Failing to call this method will cause your application to be rolled back to the previously successful version (or built-in bundle).

- Do `npm run build && npx cap copy` to copy the build to capacitor.
- Run the app and see app auto update after each backgrounding.
- Failed updates will automatically roll back to the last successful version.

See more there in the [Auto update](
https://github.com/Cap-go/capacitor-updater/wiki) documentation.


## Manual setup

Download update distribution zipfiles from a custom url. Manually control the entire update process.

- Edit your `capacitor.config.json` like below, set `autoUpdate` to true.
```json
// capacitor.config.json
{
	"appId": "**.***.**",
	"appName": "Name",
	"plugins": {
		"CapacitorUpdater": {
			"autoUpdate": false,
		}
	}
}
```
- Add to your main code
```javascript
  import { CapacitorUpdater } from '@capgo/capacitor-updater'
  CapacitorUpdater.notifyAppReady()
```
This informs Capacitor Updator that the current update bundle has loaded succesfully. Failing to call this method will cause your application to be rolled back to the previously successful version (or built-in bundle).
- Add this to your application.
```javascript
  const version = await CapacitorUpdater.download({
    url: 'https://github.com/Cap-go/demo-app/releases/download/0.0.4/dist.zip',
  })
  await CapacitorUpdater.set(version); // sets the new version, and reloads the app
```
- Failed updates will automatically roll back to the last successful version.
- Example: Using App-state to control updates, with SplashScreen:
You might also consider performing auto-update when application state changes, and using the Splash Screen to improve user experience.
```javascript
  import { CapacitorUpdater, VersionInfo } from '@capgo/capacitor-updater'
  import { SplashScreen } from '@capacitor/splash-screen'
  import { App } from '@capacitor/app'

  let version: VersionInfo;
  App.addListener('appStateChange', async (state) => {
      if (state.isActive) {
        // Ensure download occurs while the app is active, or download may fail
        version = await CapacitorUpdater.download({
          url: 'https://github.com/Cap-go/demo-app/releases/download/0.0.4/dist.zip',
        })
      }

      if (!state.isActive && version) {
        // Activate the update when the application is sent to background
        SplashScreen.show()
        try {
          await CapacitorUpdater.set(version);
          // At this point, the new version should be active, and will need to hide the splash screen
        } catch () {
          SplashScreen.hide() // Hide the splash screen again if something went wrong
        }
      }
  })

```

TIP: If you prefer a secure and automated way to update your app, you can use [capgo.app](https://capgo.app) - a full-featured, auto update system.

### Packaging `dist.zip` update bundles

Capacitor Updator works by unzipping a compiled app bundle to the native device filesystem. Whatever you choose to name the file you upload/download from your release/update server URL (via either manual or automatic updating), this `.zip` bundle must meet the following requirements:

- The zip file should contain the full contents of your production Capacitor build output folder, usually `{project directory}/dist/` or `{project directory}/www/`. This is where `index.html` will be located, and it should also contain all bundled JavaScript, CSS, and web resources necessary for your app to run.
- Do not password encrypt the bundle zip file, or it will fail to unpack.
- Make sure the bundle does not contain any extra hidden files or folders, or it may fail to unpack.

## API

<docgen-index>

* [`notifyAppReady()`](#notifyappready)
* [`download(...)`](#download)
* [`next(...)`](#next)
* [`set(...)`](#set)
* [`delete(...)`](#delete)
* [`list()`](#list)
* [`reset(...)`](#reset)
* [`current()`](#current)
* [`reload()`](#reload)
* [`setDelay(...)`](#setdelay)
* [`addListener('download', ...)`](#addlistenerdownload)
* [`addListener('downloadComplete', ...)`](#addlistenerdownloadcomplete)
* [`addListener('majorAvailable', ...)`](#addlistenermajoravailable)
* [`addListener('updateFailed', ...)`](#addlistenerupdatefailed)
* [`getId()`](#getid)
* [`getPluginVersion()`](#getpluginversion)
* [`isAutoUpdateEnabled()`](#isautoupdateenabled)
* [`addListener(string, ...)`](#addlistenerstring)
* [`removeAllListeners()`](#removealllisteners)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### notifyAppReady()

```typescript
notifyAppReady() => Promise<BundleInfo>
```

Notify Capacitor Updater that the current bundle is working (a rollback will occur of this method is not called on every app launch)

**Returns:** <code>Promise&lt;<a href="#bundleinfo">BundleInfo</a>&gt;</code>

--------------------


### download(...)

```typescript
download(options: { url: string; version?: string; }) => Promise<BundleInfo>
```

Download a new version from the provided URL, it should be a zip file, with files inside or with a unique id inside with all your files

| Param         | Type                                            |
| ------------- | ----------------------------------------------- |
| **`options`** | <code>{ url: string; version?: string; }</code> |

**Returns:** <code>Promise&lt;<a href="#bundleinfo">BundleInfo</a>&gt;</code>

--------------------


### next(...)

```typescript
next(options: { id: string; }) => Promise<BundleInfo>
```

Set the next bundle to be used when the app is reloaded.

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

**Returns:** <code>Promise&lt;<a href="#bundleinfo">BundleInfo</a>&gt;</code>

--------------------


### set(...)

```typescript
set(options: { id: string; }) => Promise<void>
```

Set the current bundle and immediately reloads the app.

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

--------------------


### delete(...)

```typescript
delete(options: { id: string; }) => Promise<void>
```

Delete bundle in storage

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

--------------------


### list()

```typescript
list() => Promise<{ bundles: BundleInfo[]; }>
```

Get all available versions

**Returns:** <code>Promise&lt;{ bundles: BundleInfo[]; }&gt;</code>

--------------------


### reset(...)

```typescript
reset(options?: { toLastSuccessful?: boolean | undefined; } | undefined) => Promise<void>
```

Set the `builtin` version (the one sent to Apple store / Google play store ) as current version

| Param         | Type                                         |
| ------------- | -------------------------------------------- |
| **`options`** | <code>{ toLastSuccessful?: boolean; }</code> |

--------------------


### current()

```typescript
current() => Promise<{ bundle: BundleInfo; native: string; }>
```

Get the current bundle, if none are set it returns `builtin`, currentNative is the original bundle installed on the device

**Returns:** <code>Promise&lt;{ bundle: <a href="#bundleinfo">BundleInfo</a>; native: string; }&gt;</code>

--------------------


### reload()

```typescript
reload() => Promise<void>
```

Reload the view

--------------------


### setDelay(...)

```typescript
setDelay(options: { delay: boolean; }) => Promise<void>
```

Set delay to skip updates in the next time the app goes into the background

| Param         | Type                             |
| ------------- | -------------------------------- |
| **`options`** | <code>{ delay: boolean; }</code> |

--------------------


### addListener('download', ...)

```typescript
addListener(eventName: 'download', listenerFunc: DownloadChangeListener) => Promise<PluginListenerHandle> & PluginListenerHandle
```

Listen for download event in the App, let you know when the download is started, loading and finished

| Param              | Type                                                                      |
| ------------------ | ------------------------------------------------------------------------- |
| **`eventName`**    | <code>'download'</code>                                                   |
| **`listenerFunc`** | <code><a href="#downloadchangelistener">DownloadChangeListener</a></code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt; & <a href="#pluginlistenerhandle">PluginListenerHandle</a></code>

**Since:** 2.0.11

--------------------


### addListener('downloadComplete', ...)

```typescript
addListener(eventName: 'downloadComplete', listenerFunc: DownloadCompleteListener) => Promise<PluginListenerHandle> & PluginListenerHandle
```

Listen for download event in the App, let you know when the download is started, loading and finished

| Param              | Type                                                                          |
| ------------------ | ----------------------------------------------------------------------------- |
| **`eventName`**    | <code>'downloadComplete'</code>                                               |
| **`listenerFunc`** | <code><a href="#downloadcompletelistener">DownloadCompleteListener</a></code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt; & <a href="#pluginlistenerhandle">PluginListenerHandle</a></code>

**Since:** 4.0.0

--------------------


### addListener('majorAvailable', ...)

```typescript
addListener(eventName: 'majorAvailable', listenerFunc: MajorAvailableListener) => Promise<PluginListenerHandle> & PluginListenerHandle
```

Listen for Major update event in the App, let you know when major update is blocked by setting disableAutoUpdateBreaking

| Param              | Type                                                                      |
| ------------------ | ------------------------------------------------------------------------- |
| **`eventName`**    | <code>'majorAvailable'</code>                                             |
| **`listenerFunc`** | <code><a href="#majoravailablelistener">MajorAvailableListener</a></code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt; & <a href="#pluginlistenerhandle">PluginListenerHandle</a></code>

**Since:** 2.3.0

--------------------


### addListener('updateFailed', ...)

```typescript
addListener(eventName: 'updateFailed', listenerFunc: UpdateFailedListener) => Promise<PluginListenerHandle> & PluginListenerHandle
```

Listen for update event in the App, let you know when update is ready to install at next app start

| Param              | Type                                                                  |
| ------------------ | --------------------------------------------------------------------- |
| **`eventName`**    | <code>'updateFailed'</code>                                           |
| **`listenerFunc`** | <code><a href="#updatefailedlistener">UpdateFailedListener</a></code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt; & <a href="#pluginlistenerhandle">PluginListenerHandle</a></code>

**Since:** 2.3.0

--------------------


### getId()

```typescript
getId() => Promise<{ id: string; }>
```

Get unique ID used to identify device (sent to auto update server)

**Returns:** <code>Promise&lt;{ id: string; }&gt;</code>

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<{ version: string; }>
```

Get the native Capacitor Updater plugin version (sent to auto update server)

**Returns:** <code>Promise&lt;{ version: string; }&gt;</code>

--------------------


### isAutoUpdateEnabled()

```typescript
isAutoUpdateEnabled() => Promise<{ enabled: boolean; }>
```

Get the state of auto update config. This will return `false` in manual mode.

**Returns:** <code>Promise&lt;{ enabled: boolean; }&gt;</code>

--------------------


### addListener(string, ...)

```typescript
addListener(eventName: string, listenerFunc: (...args: any[]) => any) => Promise<PluginListenerHandle>
```

| Param              | Type                                    |
| ------------------ | --------------------------------------- |
| **`eventName`**    | <code>string</code>                     |
| **`listenerFunc`** | <code>(...args: any[]) =&gt; any</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => Promise<void>
```

--------------------


### Interfaces


#### BundleInfo

| Prop             | Type                                                  |
| ---------------- | ----------------------------------------------------- |
| **`id`**         | <code>string</code>                                   |
| **`version`**    | <code>string</code>                                   |
| **`downloaded`** | <code>string</code>                                   |
| **`status`**     | <code><a href="#bundlestatus">BundleStatus</a></code> |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### DownloadEvent

| Prop          | Type                                              | Description                                    | Since |
| ------------- | ------------------------------------------------- | ---------------------------------------------- | ----- |
| **`percent`** | <code>number</code>                               | Current status of download, between 0 and 100. | 4.0.0 |
| **`bundle`**  | <code><a href="#bundleinfo">BundleInfo</a></code> |                                                |       |


#### DownloadCompleteEvent

| Prop         | Type                                              | Description                          | Since |
| ------------ | ------------------------------------------------- | ------------------------------------ | ----- |
| **`bundle`** | <code><a href="#bundleinfo">BundleInfo</a></code> | Emit when a new update is available. | 4.0.0 |


#### MajorAvailableEvent

| Prop          | Type                | Description                                 | Since |
| ------------- | ------------------- | ------------------------------------------- | ----- |
| **`version`** | <code>string</code> | Emit when a new major version is available. | 4.0.0 |


#### UpdateFailedEvent

| Prop         | Type                                              | Description                           | Since |
| ------------ | ------------------------------------------------- | ------------------------------------- | ----- |
| **`bundle`** | <code><a href="#bundleinfo">BundleInfo</a></code> | Emit when a update failed to install. | 4.0.0 |


### Type Aliases


#### BundleStatus

<code>'success' | 'error' | 'pending' | 'downloading'</code>


#### DownloadChangeListener

<code>(state: <a href="#downloadevent">DownloadEvent</a>): void</code>


#### DownloadCompleteListener

<code>(state: <a href="#downloadcompleteevent">DownloadCompleteEvent</a>): void</code>


#### MajorAvailableListener

<code>(state: <a href="#majoravailableevent">MajorAvailableEvent</a>): void</code>


#### UpdateFailedListener

<code>(state: <a href="#updatefailedevent">UpdateFailedEvent</a>): void</code>

</docgen-api>

### Listen to download events

```javascript
  import { CapacitorUpdater } from '@capgo/capacitor-updater';

CapacitorUpdater.addListener('download', (info: any) => {
  console.log('download was fired', info.percent);
});
```

On iOS, Apple don't allow you to show a message when the app is updated, so you can't show a progress bar.

### Inspiration

- [cordova-plugin-ionic](https://github.com/ionic-team/cordova-plugin-ionic)
- [capacitor-codepush](https://github.dev/mapiacompany/capacitor-codepush)


### Contributors

[jamesyoung1337](https://github.com/jamesyoung1337) Thanks a lot for your guidance and support, it was impossible to make this plugin work without you.
