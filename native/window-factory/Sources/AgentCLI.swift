import Foundation
import Darwin

enum AgentCLI {
    static let help = """
    Window Factory CLI (JSON results; no app UI is opened)
      window-factory status | capabilities | layouts
      window-factory windows --display ID --space ID
      window-factory capture --name NAME --display ID --space ID [--replace] [--wait]
      window-factory restore|establish --name NAME --display ID --space ID [--wait]
      window-factory job|cancel --job UUID [--wait]
    Options: --request-id UUID, --instance UUID, --wait-seconds 1...300
    Enable Agent access in Window Factory Settings → General first.
    The app must already be running. Commands never enable access or launch it.
    """
    struct Invocation {var request: AgentRequest;var waitSeconds=0}
    static func parse(_ args: [String]) throws -> Invocation {
        guard let first=args.first,let command=AgentCommand(rawValue:first) else {throw AgentFailure("invalid_command","Use --help to list commands.")}
        var request=AgentRequest(command:command),wait=0,index=1,seen=Set<String>()
        while index<args.count {
            let flag=args[index];guard seen.insert(flag).inserted else {throw AgentFailure("invalid_arguments","Duplicate option: \(flag)")};index+=1
            if flag=="--replace" {request.replace=true;continue}
            if flag=="--wait" {wait=60;continue}
            guard index<args.count else {throw AgentFailure("invalid_arguments","Missing value for \(flag).")}
            let value=args[index];index+=1
            switch flag {
            case "--name": request.name=value
            case "--display": guard let id=UInt32(value),id>0 else {throw AgentFailure("invalid_arguments","Invalid display ID.")};request.display=id
            case "--space": guard let id=UInt64(value),id>0 else {throw AgentFailure("invalid_arguments","Invalid Space ID.")};request.space=id
            case "--job": guard let id=UUID(uuidString:value) else {throw AgentFailure("invalid_arguments","Invalid job ID.")};request.jobID=id
            case "--request-id": guard let id=UUID(uuidString:value) else {throw AgentFailure("invalid_arguments","Invalid request ID.")};request.id=id
            case "--instance": guard let id=UUID(uuidString:value) else {throw AgentFailure("invalid_arguments","Invalid instance ID.")};request.instanceID=id
            case "--wait-seconds": guard let n=Int(value),(1...300).contains(n) else {throw AgentFailure("invalid_arguments","Wait must be 1–300 seconds.")};wait=n
            default: throw AgentFailure("invalid_arguments","Unknown option: \(flag)")
            }
        }
        guard !(seen.contains("--wait") && seen.contains("--wait-seconds")) else {throw AgentFailure("invalid_arguments","Choose one wait option.")}
        if wait>0 && !command.modifies && command != .job && command != .cancel {throw AgentFailure("invalid_arguments","This command has no job to wait for.")}
        try request.validate();return Invocation(request:request,waitSeconds:wait)
    }
    static func exchange(_ request: AgentRequest) throws -> AgentResponse {
        let data=try JSONEncoder().encode(request)
        do {return try AgentResponse.decode(AgentSocket.exchange(data))}
        catch {
            if !UserDefaults.standard.bool(forKey:"agentAccessEnabled") {throw AgentFailure("agent_disabled","Agent access is off. Enable it in Window Factory Settings → General.")}
            var info=stat()
            if lstat(AgentSocket.path,&info) != 0 {throw AgentFailure("not_running","The agent listener is unavailable. Open Window Factory normally; this CLI does not launch a second instance.")}
            throw error
        }
    }
    static func execute(_ args: [String],call: (AgentRequest) throws -> AgentResponse = AgentCLI.exchange) -> (Data,Int32) {
        var requestID: UUID?
        do {
            let invocation=try parse(args);requestID=invocation.request.id
            var response=try call(invocation.request)
            if invocation.waitSeconds>0,let job=response.result?.job,!job.terminal {
                let deadline=Date().addingTimeInterval(Double(invocation.waitSeconds))
                while Date()<deadline {
                    Thread.sleep(forTimeInterval:0.1)
                    var poll=AgentRequest(command:.job);poll.jobID=job.id;poll.instanceID=response.instanceID
                    do {
                        var next=try call(poll)
                        if !next.ok {
                            next.result=response.result
                            next.error=AgentFailure(next.code,"Waiting stopped; the last known job is included. Completed changes may remain. \(next.error?.message ?? "")")
                        }
                        response=next
                    }
                    catch {
                        response.ok=false;response.code="wait_interrupted";response.error=AgentFailure("wait_interrupted","The last known job is included. It may have completed changes; reconcile it before retrying. \(error.localizedDescription)");break
                    }
                    if !response.ok || response.result?.job?.terminal==true {break}
                }
                if response.ok,response.result?.job?.terminal==false {
                    response.ok=false;response.code="wait_timeout";response.error=AgentFailure("wait_timeout","Job may still be running. Poll its job ID; do not resubmit the operation.")
                }
            }
            response.requestID=invocation.request.id
            let status=response.result?.job?.status
            let exitCode:Int32 = !response.ok || ["failed","partial","cancelled"].contains(status ?? "") ? 1 : 0
            return (response.encoded(),exitCode)
        } catch {return (AgentResponse.failure(error,id:requestID).encoded(),2)}
    }
    static func run(_ args: [String]) -> Never {
        if args==["--help"] || args==["help"] {print(help);exit(0)}
        let (data,status)=execute(args);FileHandle.standardOutput.write(data);FileHandle.standardOutput.write(Data([10]));exit(status)
    }
}
