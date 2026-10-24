import Foundation

struct SwitcherSelection {
    let ids: [UInt32]
    private(set) var index: Int
    var selected: UInt32? { ids.isEmpty ? nil : ids[index] }
    init(ids: [UInt32],current: UInt32?,direction: Int) {
        var seen = Set<UInt32>(); self.ids = ids.filter{seen.insert($0).inserted}
        index = 0
        let start = current.flatMap{self.ids.firstIndex(of:$0)} ?? (direction>0 ? -1 : 0)
        if !self.ids.isEmpty { index = (start+direction%self.ids.count+self.ids.count)%self.ids.count }
    }
    mutating func advance(_ direction: Int) {
        guard !ids.isEmpty else { return }
        index = (index+direction%ids.count+ids.count)%ids.count
    }
}
struct WindowRecency {
    private(set) var ids: [UInt32] = []
    mutating func note(_ id: UInt32) {
        guard id != 0 else { return }; ids.removeAll{$0 == id}; ids.insert(id,at:0)
        if ids.count>512 { ids.removeLast(ids.count-512) }
    }
    func ordered(_ candidates: [UInt32],current: UInt32?) -> [UInt32] {
        let allowed = Set(candidates); var seen = Set<UInt32>()
        return ([current].compactMap{$0}+ids+candidates).filter{allowed.contains($0) && seen.insert($0).inserted}
    }
}
