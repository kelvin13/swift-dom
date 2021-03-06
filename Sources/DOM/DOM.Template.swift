extension DOM.Template:Equatable where Key:Equatable
{
    @inlinable public static 
    func == (lhs:Self, rhs:Self) -> Bool 
    {
        guard   lhs.literals == rhs.literals, 
                lhs.anchors.count == rhs.anchors.count 
        else 
        {
            return false 
        }
        for index:Int in lhs.anchors.indices 
            where lhs.anchors[index] != rhs.anchors[index]
        {
            return false 
        }
        return true
    }
}
extension DOM.Template:Hashable where Key:Hashable
{
    @inlinable public  
    func hash(into hasher:inout Hasher) 
    {
        self.literals.hash(into: &hasher)
        for (key, index):(Key, Int) in self.anchors 
        {
            key.hash(into: &hasher)
            index.hash(into: &hasher)
        }
    }
}

extension DOM 
{
    @frozen public
    enum Substitution<Key, Segment> where Segment:Sequence 
    {
        case key(Key)
        case segment(Segment)
    }
    
    @frozen public
    struct Template<Key> 
    {
        public
        typealias Anchor = (key:Key, index:Int)
        
        public 
        var literals:[UInt8] 
        public 
        var anchors:[Anchor]
        
        @inlinable public
        var isEmpty:Bool 
        {
            self.anchors.isEmpty && self.literals.isEmpty
        }
        
        @inlinable public 
        init(literals:[UInt8], anchors:[Anchor])
        {
            self.literals   = literals 
            self.anchors    = anchors 
        }
    }
}
extension DOM.Template where Key:Hashable
{            
    @inlinable public 
    func rendered<Segment, Output>(as _:Output.Type = Output.self, 
        substituting segments:[Key: Segment]) -> Output
        where   Output:RangeReplaceableCollection, Output.Element == UInt8,
                Segment:Collection, Segment.Element == UInt8
    {
        self.rendered(as: Output.self) { segments[$0] }
    }
}
extension DOM.Template 
{
    @inlinable public 
    func rendered<Segment, Output>(as _:Output.Type = Output.self, 
        _ render:(Key) throws -> Segment?) rethrows -> Output
        where   Output:RangeReplaceableCollection, Output.Element == UInt8,
                Segment:Collection, Segment.Element == UInt8
    {
        var output:Output = .init()
            output.reserveCapacity(self.literals.underestimatedCount)

        var start:Int = self.literals.startIndex
        for (key, index):(Key, Int) in self.anchors 
        {
            guard let segment:Segment = try render(key)
            else 
            {
                continue 
            }
            
            if  start < index 
            {
                output.append(contentsOf: self.literals[start ..< index])
                start = index 
            }
            output.append(contentsOf: segment)
        }
        if start < self.literals.endIndex 
        {
            output.append(contentsOf: self.literals[start...])
        }
        
        return output 
    }
    
    @inlinable public 
    func map<T>(_ transform:(Key) throws -> T) rethrows -> DOM.Template<T> 
        where T:Hashable 
    {
        .init(literals: self.literals, anchors: try self.anchors.map 
        { 
            (try transform($0.key), $0.index) 
        })
    }
}
extension DOM.Template 
{
    @inlinable public 
    func transform<T, Segment>(_ transform:(Key) throws -> DOM.Substitution<T, Segment>) 
        rethrows -> DOM.Template<T>
        where T:Hashable, Segment:Sequence, Segment.Element == UInt8
    {
        var iterator:Array<Anchor>.Iterator = self.anchors.makeIterator()
        var anchors:[(key:T, index:Int)] = []
        while let anchor:Anchor = iterator.next()
        {
            switch try transform(anchor.key)
            {
            case .key(let key): 
                anchors.append((key, anchor.index))
            case .segment(let segment): 
                var literals:[UInt8] = []
                    literals.reserveCapacity(self.literals.count)
                var source:Int = anchor.index
                literals.append(contentsOf: self.literals[..<source])
                literals.append(contentsOf: segment)
                while let anchor:Anchor = iterator.next()
                {
                    if  source < anchor.index 
                    {
                        literals.append(contentsOf: 
                            self.literals[source ..< anchor.index])
                        source = anchor.index 
                    }
                    switch try transform(anchor.key)
                    {
                    case .key(let key): 
                        anchors.append((key, literals.endIndex))
                    case .segment(let segment): 
                        literals.append(contentsOf: segment)
                    }
                }
                if source < self.literals.endIndex 
                {
                    literals.append(contentsOf: self.literals[source...])
                }
                return .init(literals: literals, anchors: anchors)
            }
        }
        return .init(literals: self.literals, anchors: anchors)
    }
}
extension DOM.Template 
{
    @inlinable public 
    init()
    {
        self.literals = .init()
        self.anchors = []
    }
    
    @inlinable public 
    init<Elements, Domain>(freezing elements:Elements)
        where Domain:DocumentDomain, Elements:Sequence, Elements.Element == DOM.Element<Domain, Key>
    {
        self.init()
        self.freeze(elements)
    }
    @inlinable public 
    init<Domain>(freezing element:DOM.Element<Domain, Key>)
        where Domain:DocumentDomain
    {
        self.init()
        self.freeze(element)
    }
    
    @inlinable public mutating 
    func freeze<Domain>(_ element:DOM.Element<Domain, Key>)
        where Domain:DocumentDomain
    {
        element.rendered(into: &self.literals, anchors: &self.anchors)
    }
    @inlinable public mutating 
    func freeze<Elements, Domain>(_ elements:Elements)
        where Domain:DocumentDomain, Elements:Sequence, Elements.Element == DOM.Element<Domain, Key>
    {
        for element:DOM.Element<Domain, Key> in elements 
        {
            element.rendered(into: &self.literals, anchors: &self.anchors)
        }
    }
}
extension DOM.Substitution:Sendable where Key:Sendable, Segment:Sendable
{
}
extension DOM.Template:Sendable where Key:Sendable
{
}

extension DOM.Element where Anchor == Never
{
    @inlinable public 
    func rendered<UTF8>(as _:UTF8.Type) -> UTF8
        where UTF8:RangeReplaceableCollection, UTF8.Element == UInt8
    {
        var output:UTF8 = .init()
        var anchors:[(key:Anchor, index:UTF8.Index)] = []
        self.rendered(into: &output, anchors: &anchors)
        return output 
    }
    @inlinable public 
    func rendered<UTF8>(into output:inout UTF8)
        where UTF8:RangeReplaceableCollection, UTF8.Element == UInt8
    {
        var anchors:[(key:Anchor, index:UTF8.Index)] = []
        self.rendered(into: &output, anchors: &anchors)
    }
}
extension DOM.Element 
{
    @inlinable public 
    func rendered<UTF8>(into output:inout UTF8, anchors:inout [(key:Anchor, index:UTF8.Index)]) 
        where UTF8:RangeReplaceableCollection, UTF8.Element == UInt8
    {
        let attributes:[Attribute], 
            children:[Self]??, 
            type:String
        switch self 
        {
        case .bytes     (utf8: let utf8):
            output.append(contentsOf:      utf8)
            return
        case .text      (escaped: let text):
            output.append(contentsOf: text.utf8)
            return 
        
        case .leaf      (let element, attributes: let items): 
            attributes  = items
            children    = element.void ? .none : .some(nil) 
            type        = element.name
        case .container (let element, attributes: let items, content: let content):
            attributes  = items
            children    = .some(content)
            type        = element.name
        
        case .anchor    (let key):
            anchors.append((key, output.endIndex))
            return 
        }
        
        output.append(0x3c) // '<'
        output.append(contentsOf: type.utf8) 
        for (key, value):(String, Value) in attributes
        { 
            // ' '
            output.append(                               0x20)
            output.append(contentsOf: key.utf8)
            switch value 
            {
            case .void: 
                break
            case .text(let string):
                // '="'
                output.append(contentsOf:         [0x3d, 0x22])
                output.append(contentsOf: string.utf8)
                // '"'
                output.append(                           0x22)
            case .anchor(let key):
                // '="'
                output.append(contentsOf:         [0x3d, 0x22])
                anchors.append((key, output.endIndex))
                // '"'
                output.append(                           0x22)
            }
        }
        guard let enclosed:[Self]?  = children 
        else 
        {
            output.append(0x3e) // '>'
            return 
        }
        guard let content:[Self]    = enclosed
        else 
        {
            output.append(contentsOf: [0x2f, 0x3e]) // '/>'
            return 
        }
        
        output.append(0x3e) // '>'
        for child:Self in content 
        {
            child.rendered(into: &output, anchors: &anchors)
        }
        output.append(contentsOf: [0x3c, 0x2f]) // '</'
        output.append(contentsOf: type.utf8) 
        output.append(0x3e) // '>'
    }
}
