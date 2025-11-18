
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

    // Serve static files from the public directory at root path
    // This should come before API routes to prioritize static files
    server.add(new serve.Static('/', '../../public', {
        index: 'index.html',
        maxAge: 3600, // Cache for 1 hour
        etag: true,
        dotfiles: 'ignore',
        extensions: ['html', 'htm'] // Try these extensions if file not found
    }));

    // Example: You could also mount static files at a subdirectory
    // server.add(new serve.Static('/assets', '../../assets'));

    // Add API routes
    server.add(new App());

    // Start server
    server.start();

    #if php
    trace('Server is ready to handle requests');
    trace('Access static files at: http://localhost:8000/');
    trace('API endpoints at: http://localhost:8000/api/test');
    #elseif nodejs
    trace('Static files available at: http://localhost:3000/');
    trace('API endpoint at: http://localhost:3000/api/test');
    #end

}
