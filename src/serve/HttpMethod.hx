package serve;

enum abstract HttpMethod(Int) from Int to Int {

    var GET = 1;

    var POST = 2;

    var PUT = 3;

    var DELETE = 4;

    public function toString() {
        return switch abstract {
            case GET: 'GET';
            case POST: 'POST';
            case PUT: 'PUT';
            case DELETE: 'DELETE';
        }
    }

}
