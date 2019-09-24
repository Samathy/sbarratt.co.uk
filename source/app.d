import std.stdio;
import std.file: readText, read, exists;
import vibe.http.server;
import vibe.http.fileserver;
import vibe.http.router;
import vibe.textfilter.markdown;
import vibe.core.core: runApplication;

/// Renders a markdown file from the 'blog' directory.
void handleBlogRequest( scope HTTPServerRequest req, scope HTTPServerResponse res)
{
    auto path = req.requestPath.toString()[1..$];

    if ( !exists("public/"~path))
    { 
      res.render!("404.dt"); 
      return;
    }

    string postText = readText("public/"~path);
    string content = filterMarkdown(postText);

    res.render!("basic.dt", content);

}

/// Renders a markdown file from the 'public' directory.
void handleStandardRequest ( scope HTTPServerRequest req, scope HTTPServerResponse res)
{
    auto path = req.requestPath.toString()[1..$];

    if ( !exists("public/"~path))
    { 
      res.render!("404.dt"); 
      return;
    }

    string contentMD = readText("public/"~path);
    string content = filterMarkdown(contentMD);
    string css = "basic";

    res.render!("basic.dt", content);
}

/// Always renders index.
void index ( scope HTTPServerRequest req, scope HTTPServerResponse res)
{
    auto path = req.requestPath;
    string contentMD = readText("public/index");
    string content = filterMarkdown(contentMD);
    res.render!("basic.dt", content);
}

int main()
{

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["::1", "127.0.0.1"];

    auto router = new URLRouter;
    
    router.get("/", &index);
    router.get("*", &handleStandardRequest);
    router.get("/blog", &handleBlogRequest);

    auto listener = listenHTTP(settings, router);

    scope(exit) listener.stopListening();

    runApplication();

    return 0;
}
