import Foundation
@main enum SwitcherTests {
 static func main() {
    var assertions = 0
    func check(_ condition: Bool,_ label: String) { precondition(condition,label); assertions += 1 }
    for count in 1...8 {
        let ids = (1...count).map{UInt32($0)}
        for current in 0..<count { for direction in [-1,1] {
            var selection = SwitcherSelection(ids:ids,current:ids[current],direction:direction)
            check(selection.selected == ids[(current+direction+count)%count],"Fresh forward/reverse selection matches original switcher")
            for step in 1...count*2 {
                selection.advance(direction)
                let expected = ((current+(step+1)*direction)%count+count)%count
                check(selection.selected == ids[expected],"Repeated cycle wraps")
            }
            let before = selection.selected
            selection.advance(-direction); selection.advance(direction)
            check(selection.selected == before,"Direction change is reversible in frozen session")
        } }
    }
    check(SwitcherSelection(ids:[],current:nil,direction:1).selected == nil,"Empty list")
    check(SwitcherSelection(ids:[2,3],current:nil,direction:1).selected == 2,"Absent source forward selects first")
    check(SwitcherSelection(ids:[2,3],current:99,direction:-1).selected == 3,"Absent source reverse selects last")
    check(SwitcherSelection(ids:[1,1,2],current:1,direction:1).selected == 2,"Deduplicate identities")
    var recency = WindowRecency(); recency.note(3); recency.note(2); recency.note(3)
    check(recency.ids == [3,2],"Latest focus promoted without duplicate")
    check(recency.ordered([1,2,3,4],current:1) == [1,3,2,4],"Current first, observed recency, initial stacking order")
    check(recency.ordered([1,4,4],current:99) == [1,4],"Closed candidates and absent source excluded")
    for id in 1...600 { recency.note(UInt32(id)) }
    check(recency.ids.count == 512 && recency.ids.first == 600,"Bounded memory-only history")
    print("native window switching: \(assertions) assertions passed")
 }
}
