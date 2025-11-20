package serve;

abstract Headers(Array<String>) {

    public function new() {
        this = [];
    }

    public function add(name:String, value:String):Void {
        this.push(name);
        this.push(value);
    }

    public function remove(name:String):Void {
        var i:Int = 0;
        while (i < this.length) {
            if (this[i] == name) {
                this.splice(i, 2);
            }
            else {
                i += 2;
            }
        }
    }

    public inline function keyValueIterator():HeadersKeyValueIterator {
        return new HeadersKeyValueIterator(this);
    }

}

private class HeadersKeyValueIterator {
    var array:Array<String>;
    var index:Int;

    public inline function new(array:Array<String>) {
        this.array = array;
        this.index = 0;
    }

    public inline function hasNext():Bool {
        return index < array.length;
    }

    public inline function next():{key:String, value:String} {
        final key = array[index];
        index++;
        final value = array[index];
        index++;
        return {
            key: key,
            value: value
        };
    }
}

