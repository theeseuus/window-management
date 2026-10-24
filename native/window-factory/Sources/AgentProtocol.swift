import Foundation

enum AgentCommand: String,Codable,CaseIterable {
    case status,capabilities,layouts,windows,capture,restore,establish,job,cancel
    var modifies: Bool { [.capture,.restore,.establish].contains(self) }
}
struct AgentRequest: Codable,Equatable {
    var version = 1
    var id = UUID()
    var command: AgentCommand
    var name: String?
    var display: UInt32?
    var space: UInt64?
    var jobID: UUID?
    var replace = false
    var instanceID: UUID?
    func validate() throws {
        guard version == 1 else { throw AgentFailure("unsupported_version","Use protocol version 1.") }
        if command.modifies || command == .windows {
            guard let display,display>0,let space,space>0 else { throw AgentFailure("context_required","Supply --display and --space from status.") }
        } else if display != nil || space != nil { throw AgentFailure("invalid_request","This command does not take a desktop context.") }
        if command.modifies {
            guard let name,try Recipe.normalizedName(name) == name else { throw AgentFailure("invalid_name","Supply a valid layout name.") }
        } else if name != nil { throw AgentFailure("invalid_request","This command does not take a layout name.") }
        if command == .job || command == .cancel {
            guard jobID != nil else { throw AgentFailure("job_required","Supply --job with the returned job ID.") }
        } else if jobID != nil { throw AgentFailure("invalid_request","This command does not take a job ID.") }
        if replace && command != .capture { throw AgentFailure("invalid_request","--replace applies only to Capture.") }
    }
    static func decode(_ data: Data) throws -> Self {
        let object: Any
        do {object = try JSONSerialization.jsonObject(with:data)} catch {throw AgentFailure("invalid_request","Malformed JSON request.")}
        guard let fields = object as? [String:Any],
              Set(fields.keys).isSubset(of:["version","id","command","name","display","space","jobID","replace","instanceID"]) else { throw AgentFailure("invalid_request","Unknown request fields.") }
        let request: Self
        do {request = try JSONDecoder().decode(Self.self,from:data)} catch {throw AgentFailure("invalid_request","Malformed protocol request.")}
        try request.validate(); return request
    }
}
struct AgentFailure: Error,LocalizedError,Codable {
    let code: String,message: String
    init(_ code: String,_ message: String) { self.code=code;self.message=message }
    var errorDescription: String? { message }
}
struct AgentDesktop: Codable {
    let display: UInt32,space: UInt64,frame: Frame
}
struct AgentWindow: Codable {
    let id: UInt32,pid: Int32,bundleID: String,appName: String,frame: Frame
}
struct AgentStatus: Codable {
    let instanceID: UUID,agentAccess: Bool,accessibility: Bool,busy: Bool
    let desktops: [AgentDesktop]
}
struct AgentJob: Codable {
    let id: UUID,requestID: UUID,command: AgentCommand,name: String,context: AgentDesktop,startedAt: Date
    var status = "running",progress = "Starting"
    var finishedAt: Date?
    var receipt: Receipt?
    var recipe: Recipe?
    var error: AgentFailure?
    var sideEffectsPossible = false
    var terminal: Bool { status != "running" }
}
struct AgentPayload: Codable {
    var status: AgentStatus?
    var commands: [String]?
    var layouts: [Recipe]?
    var windows: [AgentWindow]?
    var job: AgentJob?
}
struct AgentResponse: Codable {
    var version = 1
    var requestID: UUID?
    var instanceID: UUID?
    var ok: Bool
    var code: String
    var result: AgentPayload?
    var error: AgentFailure?
    static func failure(_ error: Error,id: UUID? = nil,instance: UUID? = nil) -> Self {
        let failure = error as? AgentFailure ?? AgentFailure("operation_failed",error.localizedDescription)
        return Self(requestID:id,instanceID:instance,ok:false,code:failure.code,error:failure)
    }
    func encoded() -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)) ?? Data("{\"version\":1,\"ok\":false,\"code\":\"encoding_failed\"}".utf8)
    }
    static func decode(_ data: Data) throws -> Self {
        let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self,from:data)
    }
}
