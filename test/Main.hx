
import serve.Server;

function main() {

    // Create server and bind it to app/router
    var server = new Server(
        #if php
        new serve.PhpBackend()
        #elseif nodejs
        new serve.NodeJsBackend(3000, "localhost")
        #end
    );

    // Assign app/router
    server.add(new App());

    // Start server
    server.start();

}
