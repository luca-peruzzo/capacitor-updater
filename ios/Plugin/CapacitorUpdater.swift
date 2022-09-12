import Foundation
import SSZipArchive
import Alamofire
import zlib

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
    var exist: Bool {
        return FileManager().fileExists(atPath: self.path)
    }
}
extension Date {
    func adding(minutes: Int) -> Date {
        return Calendar.current.date(byAdding: .minute, value: minutes, to: self)!
    }
}
struct AppVersionDec: Decodable {
    let version: String?
    let url: String?
    let message: String?
    let major: Bool?
}
public class AppVersion: NSObject {
    var version: String = ""
    var url: String = ""
    var message: String?
    var major: Bool?
}

extension AppVersion {
    func toDict() -> [String:Any] {
        var dict = [String:Any]()
        let otherSelf = Mirror(reflecting: self)
        for child in otherSelf.children {
            if let key = child.label {
                dict[key] = child.value
            }
        }
        return dict
    }
}

extension OperatingSystemVersion {
    func getFullVersion(separator: String = ".") -> String {
        return "\(majorVersion)\(separator)\(minorVersion)\(separator)\(patchVersion)"
    }
}
extension Bundle {
    var versionName: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var versionCode: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

extension ISO8601DateFormatter {
    convenience init(_ formatOptions: Options) {
        self.init()
        self.formatOptions = formatOptions
    }
}
extension Formatter {
    static let iso8601withFractionalSeconds = ISO8601DateFormatter([.withInternetDateTime, .withFractionalSeconds])
}
extension Date {
    var iso8601withFractionalSeconds: String { return Formatter.iso8601withFractionalSeconds.string(from: self) }
}
extension String {
    
    var fileURL: URL {
        return URL(fileURLWithPath: self)
    }
    
    var lastPathComponent:String {
        get {
            return fileURL.lastPathComponent
        }
    }
    var iso8601withFractionalSeconds: Date? {
        return Formatter.iso8601withFractionalSeconds.date(from: self)
    }
    func trim(using characterSet: CharacterSet = .whitespacesAndNewlines) -> String {
        return trimmingCharacters(in: characterSet)
    }
}

enum CustomError: Error {
    // Throw when an unzip fail
    case cannotUnzip
    case cannotUnflat
    case cannotCreateDirectory
    case cannotDeleteDirectory

    // Throw in all other cases
    case unexpected(code: Int)
}

extension CustomError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cannotUnzip:
            return NSLocalizedString(
                "The file cannot be unzip",
                comment: "Invalid zip"
            )
        case .cannotCreateDirectory:
            return NSLocalizedString(
                "The folder cannot be created",
                comment: "Invalid folder"
            )
        case .cannotDeleteDirectory:
            return NSLocalizedString(
                "The folder cannot be deleted",
                comment: "Invalid folder"
            )
        case .cannotUnflat:
            return NSLocalizedString(
                "The file cannot be unflat",
                comment: "Invalid folder"
            )
        case .unexpected(_):
            return NSLocalizedString(
                "An unexpected error occurred.",
                comment: "Unexpected Error"
            )
        }
    }
}

@objc public class CapacitorUpdater: NSObject {
    
    private let versionName = Bundle.main.versionName ?? ""
    private let versionCode = Bundle.main.versionCode ?? ""
    private let versionOs = ProcessInfo().operatingSystemVersion.getFullVersion()
    private let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    private let bundleDirectoryHot = "versions"
    private let DEFAULT_FOLDER = ""
    private let bundleDirectory = "NoCloud/ionic_built_snapshots"
    private let INFO_SUFFIX = "_info"
    private let FALLBACK_VERSION = "pastVersion"
    private let NEXT_VERSION = "nextVersion"
    
    public let TAG = "✨  Capacitor-updater:";
    public let CAP_SERVER_PATH = "serverBasePath"
    public let pluginVersion = "4.2.1"
    public var statsUrl = ""
    public var appId = ""
    public var deviceID = UIDevice.current.identifierForVendor?.uuidString ?? ""
    
    public var notifyDownload: (String, Int) -> Void = { _,_  in }

    private func calcTotalPercent(percent: Int, min: Int, max: Int) -> Int {
        return (percent * (max - min)) / 100 + min;
    }
    
    private func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    // Persistent path /var/mobile/Containers/Data/Application/8C0C07BE-0FD3-4FD4-B7DF-90A88E12B8C3/Library/NoCloud/ionic_built_snapshots/FOLDER
    // Hot Reload path /var/mobile/Containers/Data/Application/8C0C07BE-0FD3-4FD4-B7DF-90A88E12B8C3/Documents/FOLDER
    // Normal /private/var/containers/Bundle/Application/8C0C07BE-0FD3-4FD4-B7DF-90A88E12B8C3/App.app/public
    
    private func prepareFolder(source: URL) throws {
        if (!FileManager.default.fileExists(atPath: source.path)) {
            do {
                try FileManager.default.createDirectory(atPath: source.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("\(self.TAG) Cannot createDirectory \(source.path)")
                throw CustomError.cannotCreateDirectory
            }
        }
    }
    
    private func deleteFolder(source: URL) throws {
        do {
            try FileManager.default.removeItem(atPath: source.path)
        } catch {
            print("\(self.TAG) File not removed. \(source.path)")
            throw CustomError.cannotDeleteDirectory
        }
    }
    
    private func unflatFolder(source: URL, dest: URL) throws -> Bool {
        let index = source.appendingPathComponent("index.html")
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: source.path)
            if (files.count == 1 && source.appendingPathComponent(files[0]).isDirectory && !FileManager.default.fileExists(atPath: index.path)) {
                try FileManager.default.moveItem(at: source.appendingPathComponent(files[0]), to: dest)
                return true
            } else {
                try FileManager.default.moveItem(at: source, to: dest)
                return false
            }
        } catch {
            print("\(self.TAG) File not moved. source: \(source.path) dest: \(dest.path)")
            throw CustomError.cannotUnflat
        }
    }

    private func getChecksum(filePath: URL) -> String {
        do {
            let fileData = try Data.init(contentsOf: filePath)
            let checksum = fileData.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(fileData.count)) }
            return String(format:"%08X", checksum).lowercased()
        } catch {
            print("\(self.TAG) Cannot get checksum: \(filePath.path)", error)
            return ""
        }
    }
    
    private func saveDownloaded(sourceZip: URL, id: String, base: URL) throws  {
        try prepareFolder(source: base)
        let destHot = base.appendingPathComponent(id)
        let destUnZip = documentsDir.appendingPathComponent(randomString(length: 10))
        if (!SSZipArchive.unzipFile(atPath: sourceZip.path, toDestination: destUnZip.path)) {
            throw CustomError.cannotUnzip
        }
        if (try unflatFolder(source: destUnZip, dest: destHot)) {
            try deleteFolder(source: destUnZip)
        }
    }

    public func getLatest(url: URL) -> AppVersion {
        let semaphore = DispatchSemaphore(value: 0)
        let latest = AppVersion()
        let parameters: [String: String] = [
            "platform": "ios",
            "device_id": self.deviceID,
            "app_id": self.appId,
            "version_build": self.versionName,
            "version_code": self.versionCode,
            "version_os": self.versionOs,
            "plugin_version": self.pluginVersion,
            "version_name": self.getCurrentBundle().getVersionName()
        ]
        print("\(self.TAG) Auto-update parameters: \(parameters)")
        let request = AF.request(url, method: .post,parameters: parameters, encoder: JSONParameterEncoder.default)

        request.validate().responseDecodable(of: AppVersionDec.self) { response in
            switch response.result {
                case .success:
                    if let url = response.value?.url {
                        latest.url = url
                    }
                    if let version = response.value?.version {
                        latest.version = version
                    }
                    if let major = response.value?.major {
                        latest.major = major
                    }
                    if let message = response.value?.message {
                        latest.message = message
                    }
                case let .failure(error):
                    print("\(self.TAG) Error getting Latest", error )
            }
            semaphore.signal()
        }
        semaphore.wait()
        return latest
    }
    
    private func setCurrentBundle(bundle: String) {
        UserDefaults.standard.set(bundle, forKey: self.CAP_SERVER_PATH)
        UserDefaults.standard.synchronize()
        print("\(self.TAG) Current bundle set to: \(bundle == "" ? BundleInfo.ID_BUILTIN : bundle)")
    }

    public func download(url: URL, version: String) throws -> BundleInfo {
        let semaphore = DispatchSemaphore(value: 0)
        let id: String = self.randomString(length: 10)
        var checksum = ""
        var mainError: NSError? = nil
        let destination: DownloadRequest.Destination = { _, _ in
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent(self.randomString(length: 10))

            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        let request = AF.download(url, to: destination)
        
        request.downloadProgress { progress in
            let percent = self.calcTotalPercent(percent: Int(progress.fractionCompleted * 100), min: 10, max: 70)
            self.notifyDownload(id, percent)
        }
        request.responseURL { (response) in
            if let fileURL = response.fileURL {
                switch response.result {
                case .success:
                    self.notifyDownload(id, 71)
                    do {
                        checksum = self.getChecksum(filePath: fileURL)
                        try self.saveDownloaded(sourceZip: fileURL, id: id, base: self.documentsDir.appendingPathComponent(self.bundleDirectoryHot))
                        self.notifyDownload(id, 85)
                        try self.saveDownloaded(sourceZip: fileURL, id: id, base: self.libraryDir.appendingPathComponent(self.bundleDirectory))
                        self.notifyDownload(id, 100)
                        try self.deleteFolder(source: fileURL)
                    } catch {
                        print("\(self.TAG) download unzip error", error)
                        mainError = error as NSError
                    }
                case let .failure(error):
                    print("\(self.TAG) download error", error)
                    mainError = error as NSError
                }
            }
            semaphore.signal()
        }
        self.saveBundleInfo(id: id, bundle: BundleInfo(id: id, version: version, status: BundleStatus.DOWNLOADING, downloaded: Date(), checksum: checksum))
        self.notifyDownload(id, 0)
        semaphore.wait()
        if (mainError != nil) {
            throw mainError!
        }
        let info: BundleInfo = BundleInfo(id: id, version: version, status: BundleStatus.PENDING, downloaded: Date(), checksum: checksum)
        self.saveBundleInfo(id: id, bundle: info)
        return info
    }

    public func list() -> [BundleInfo] {
        let dest = documentsDir.appendingPathComponent(bundleDirectoryHot)
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: dest.path)
            var res: [BundleInfo] = []
            print("\(self.TAG) list File : \(dest.path)")
            if (dest.exist) {
                for id in files {
                    res.append(self.getBundleInfo(id: id));
                }
            }
            return res
        } catch {
            print("\(self.TAG) No version available \(dest.path)")
            return []
        }
    }
    
    public func delete(id: String, removeInfo: Bool) -> Bool {
        let deleted: BundleInfo = self.getBundleInfo(id: id)
        if (deleted.isBuiltin() || self.getCurrentBundleId() == id) {
            print("\(self.TAG) Cannot delete \(id)")
            return false
        }
        let destHot = documentsDir.appendingPathComponent(bundleDirectoryHot).appendingPathComponent(id)
        let destPersist = libraryDir.appendingPathComponent(bundleDirectory).appendingPathComponent(id)
        do {
            try FileManager.default.removeItem(atPath: destHot.path)
        } catch {
            print("\(self.TAG) Hot Folder \(destHot.path), not removed.")
        }
        do {
            try FileManager.default.removeItem(atPath: destPersist.path)
        } catch {
            print("\(self.TAG) Folder \(destPersist.path), not removed.")
            return false
        }
        if (removeInfo) {
            self.removeBundleInfo(id: id)
        }
        self.removeBundleInfo(id: id)
        self.sendStats(action: "delete", versionName: deleted.getVersionName())
        return true
    }

    public func delete(id: String) -> Bool {
        return self.delete(id: id, removeInfo: true)
    }

    public func getBundleDirectory(id: String) -> URL {
        return libraryDir.appendingPathComponent(self.bundleDirectory).appendingPathComponent(id)
    }

    public func set(bundle: BundleInfo) -> Bool {
        return self.set(id: bundle.getId());
    }

    private func bundleExists(id: String) -> Bool {
        let destHot = self.getPathHot(id: id)
        let destHotPersist = self.getPathPersist(id: id)
        let indexHot = destHot.appendingPathComponent("index.html")
        let indexPersist = destHotPersist.appendingPathComponent("index.html")
        let url: URL = self.getBundleDirectory(id: id)
        if(url.isDirectory && destHotPersist.isDirectory && indexHot.exist && indexPersist.exist) {
            return true;
        }
        return false;
    }

    public func set(id: String) -> Bool {
        let newBundle: BundleInfo = self.getBundleInfo(id: id)
        if(newBundle.isBuiltin()) {
            self.reset()
            return true
        }
        if (bundleExists(id: id)) {
            self.setCurrentBundle(bundle: self.getBundleDirectory(id: id).path)
            self.setBundleStatus(id: id, status: BundleStatus.PENDING)
            sendStats(action: "set", versionName: newBundle.getVersionName())
            return true
        }
        sendStats(action: "set_fail", versionName: newBundle.getVersionName())
        return false
    }
    
    public func getPathHot(id: String) -> URL {
        return documentsDir.appendingPathComponent(self.bundleDirectoryHot).appendingPathComponent(id)
    }
    
    public func getPathPersist(id: String) -> URL {
        return libraryDir.appendingPathComponent(self.bundleDirectory).appendingPathComponent(id)
    }
    
    public func reset() {
        self.reset(isInternal: false)
    }
    
    public func reset(isInternal: Bool) {
        print("\(self.TAG) reset: \(isInternal)")
        self.setCurrentBundle(bundle: "")
        self.setFallbackBundle(fallback: Optional<BundleInfo>.none)
        let _ = self.setNextBundle(next: Optional<String>.none)
        if(!isInternal) {
            sendStats(action: "reset", versionName: self.getCurrentBundle().getVersionName())
        }
    }
    
    public func setSuccess(bundle: BundleInfo, autoDeletePrevious: Bool) {
        self.setBundleStatus(id: bundle.getId(), status: BundleStatus.SUCCESS)
        let fallback: BundleInfo = self.getFallbackBundle()
        print("\(self.TAG) Fallback bundle is: \(fallback.toString())")
        print("\(self.TAG) Version successfully loaded: \(bundle.toString())")
        if(autoDeletePrevious && !fallback.isBuiltin()) {
            let res = self.delete(id: fallback.getId())
            if (res) {
                print("\(self.TAG) Deleted previous bundle: \(fallback.toString())")
            } else {
                print("\(self.TAG) Failed to delete previous bundle: \(fallback.toString())")
            }
        }
        self.setFallbackBundle(fallback: bundle)
    }
    
    public func setError(bundle: BundleInfo) {
        self.setBundleStatus(id: bundle.getId(), status: BundleStatus.ERROR);
    }

    func sendStats(action: String, versionName: String) {
        if (statsUrl == "") { return }
        let parameters: [String: String] = [
            "platform": "ios",
            "action": action,
            "device_id": self.deviceID,
            "version_name": versionName,
            "version_build": self.versionName,
            "version_code": self.versionCode,
            "version_os": self.versionOs,
            "plugin_version": self.pluginVersion,
            "app_id": self.appId
        ]
        DispatchQueue.global(qos: .background).async {
            let request = AF.request(self.statsUrl, method: .post,parameters: parameters, encoder: JSONParameterEncoder.default)
            request.responseData { response in
                switch response.result {
                case .success:
                    print("\(self.TAG) Stats send for \(action), version \(versionName)")
                case let .failure(error):
                    print("\(self.TAG) Error sending stats: ", error )
                }
            }
        }
    }

    public func getBundleInfo(id: String?) -> BundleInfo {
        var trueId = BundleInfo.VERSION_UNKNOWN
        if(id != nil) {
            trueId = id!
        }
        print("\(self.TAG) Getting info for bundle [\(trueId)]")
        let result: BundleInfo;
        if(BundleInfo.ID_BUILTIN == trueId) {
            result = BundleInfo(id: trueId, version: "", status: BundleStatus.SUCCESS, checksum: "")
        } else if (BundleInfo.VERSION_UNKNOWN == trueId) {
            result = BundleInfo(id: trueId, version: "", status: BundleStatus.ERROR, checksum: "")
        } else {
            do {
                result = try UserDefaults.standard.getObj(forKey: "\(trueId)\(self.INFO_SUFFIX)", castTo: BundleInfo.self)
            } catch {
                print("\(self.TAG) Failed to parse info for bundle [\(trueId)]", error.localizedDescription)
                result = BundleInfo(id: trueId, version: "", status: BundleStatus.PENDING, checksum: "")
            }
        }
        print("\(self.TAG) Returning info bundle [\(result.toString())]")
        return result;
    }

    public func getBundleInfoByVersionName(version: String) -> BundleInfo? {
        let installed : Array<BundleInfo> = self.list()
        for i in installed {
            if(i.getVersionName() == version) {
                return i
            }
        }
        return nil
    }

    private func removeBundleInfo(id: String) {
        self.saveBundleInfo(id: id, bundle: nil)
    }

    private func saveBundleInfo(id: String, bundle: BundleInfo?) {
        if (bundle != nil && (bundle!.isBuiltin() || bundle!.isUnknown())) {
            print("\(self.TAG) Not saving info for bundle [\(id)]", bundle!.toString())
            return
        }
        if(bundle == nil) {
            print("\(self.TAG) Removing info for bundle [\(id)]")
            UserDefaults.standard.removeObject(forKey: "\(id)\(self.INFO_SUFFIX)")
        } else {
            let update = bundle!.setId(id: id)
            print("\(self.TAG) Storing info for bundle [\(id)]", update.toString())
            do {
                try UserDefaults.standard.setObj(update, forKey: "\(id)\(self.INFO_SUFFIX)")
            } catch {
                print("\(self.TAG) Failed to save info for bundle [\(id)]", error.localizedDescription)
            }
        }
        UserDefaults.standard.synchronize()
    }

    public func setVersionName(id: String, version: String) {
        print("\(self.TAG) Setting version for folder [\(id)] to \(version)")
        let info = self.getBundleInfo(id: id)
        self.saveBundleInfo(id: id, bundle: info.setVersionName(version: version))
    }

    private func setBundleStatus(id: String, status: BundleStatus) {
        print("\(self.TAG) Setting status for bundle [\(id)] to \(status)")
        let info = self.getBundleInfo(id: id)
        self.saveBundleInfo(id: id, bundle: info.setStatus(status: status.localizedString))
    }

    public func getCurrentBundle() -> BundleInfo {
        return self.getBundleInfo(id: self.getCurrentBundleId());
    }

    public func getCurrentBundleId() -> String {
        guard let bundlePath = UserDefaults.standard.string(forKey: self.CAP_SERVER_PATH) else {
            return BundleInfo.ID_BUILTIN
        }
        if (bundlePath == "") {
            return BundleInfo.ID_BUILTIN
        }
        let bundleID = bundlePath.components(separatedBy: "/").last ?? bundlePath
        return bundleID
    }

    public func isUsingBuiltin() -> Bool {
        return (UserDefaults.standard.string(forKey: self.CAP_SERVER_PATH) ?? "") == self.DEFAULT_FOLDER
    }

    public func getFallbackBundle() -> BundleInfo {
        let id: String = UserDefaults.standard.string(forKey: self.FALLBACK_VERSION) ?? BundleInfo.ID_BUILTIN
        return self.getBundleInfo(id: id)
    }

    private func setFallbackBundle(fallback: BundleInfo?) {
        UserDefaults.standard.set(fallback == nil ? BundleInfo.ID_BUILTIN : fallback!.getId(), forKey: self.FALLBACK_VERSION)
        UserDefaults.standard.synchronize()
    }

    public func getNextBundle() -> BundleInfo? {
        let id: String? = UserDefaults.standard.string(forKey: self.NEXT_VERSION)
        return self.getBundleInfo(id: id)
    }

    public func setNextBundle(next: String?) -> Bool {
        guard let nextId = next else {
            UserDefaults.standard.removeObject(forKey: self.NEXT_VERSION)
            UserDefaults.standard.synchronize()
            return false
        }
        let newBundle: BundleInfo = self.getBundleInfo(id: nextId)
        let bundle: URL = self.getBundleDirectory(id: nextId)
        if (!newBundle.isBuiltin() && !bundle.exist) {
            return false
        }
        UserDefaults.standard.set(nextId, forKey: self.NEXT_VERSION)
        UserDefaults.standard.synchronize()
        self.setBundleStatus(id: nextId, status: BundleStatus.PENDING)
        return true
    }
}
