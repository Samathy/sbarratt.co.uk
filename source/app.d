import std.stdio;
import std.file : readText, read, exists, dirEntries, SpanMode, isFile;
import std.algorithm : sort;
import std.string : split;
import vibe.http.server;
import vibe.http.fileserver;
import vibe.http.router;
import vibe.textfilter.markdown;
import vibe.core.core : runApplication;

string[] getBlogFiles()
{
    string[] files;

    foreach (string name; dirEntries("public/blog/", SpanMode.breadth))
    {
        if (name.isFile())
        {
            string filename = name.split("/")[2];
            files = files ~ filename;
        }
    }

    return files;
}

/// Returns next blog post, if one exists.
string nextBlogPost(string currentPost)
{
    string[] files = getBlogFiles();

    auto filesSorted = files.sort();

    int i = 0;
    foreach (string name; files)
    {
        if (name == currentPost)
        {
            if (i + 1 < files.length)
            {
                return files[i + 1];
            }
            else
            {
                return name;
            }
        }

        i += 1;
    }

    return currentPost;
}

/// Returns previous blog post - if one exists.
string previousBlogPost(string currentPost)
{
    string[] files = getBlogFiles();

    auto filesSorted = files.sort();

    string prev;

    int i = 0;
    foreach (string name; files)
    {
        if (name == currentPost)
        {
            if (i - 1 >= 0)
            {
                return files[i - 1];
            }
            else
            {
                return name;
            }
        }
        i += 1;
    }
    return currentPost;

}

/// Renders a markdown file from the 'blog' directory.
void handleBlogRequest(scope HTTPServerRequest req, scope HTTPServerResponse res)
{
    auto path = req.requestPath.toString()[1 .. $];

    // If we havent requested anything in particular
    // load the latest
    if (path.split("/")[$ - 1] == "blog")
    {
        path = "blog/latest";
    }

    // Latest always points to most recent
    if (path.split("/")[$ - 1] == "latest")
    {
        string[] files = getBlogFiles();
        writeln(files.sort());
        path = "blog/" ~ files.sort()[$ - 1];
    }

    // If the post doesnt exist, or we're displaying nothing.
    if (!exists("public/" ~ path) || path == "blog/")
    {
        res.render!("404.dt");
        return;
    }

    string postText = readText("public/" ~ path);
    string content = filterMarkdown(postText);

    string next = nextBlogPost(path[5 .. $]);
    string prev = previousBlogPost(path[5 .. $]);

    string perma = "https://sbarratt.co.uk/blog/" ~ path[5 .. $];

    res.render!("blog.dt", content, next, prev, perma);

}

/// Renders a markdown file from the 'public' directory.
void handleStandardRequest(scope HTTPServerRequest req, scope HTTPServerResponse res)
{
    auto path = req.requestPath.toString()[1 .. $];

    if (!exists("public/" ~ path) && isFile("public/" ~ path))
    {
        res.render!("404.dt");
        return;
    }

    string contentMD = readText("public/" ~ path);
    string content = filterMarkdown(contentMD);
    string css = "basic";

    res.render!("basic.dt", content);
}

/// Always renders index.
void index(scope HTTPServerRequest req, scope HTTPServerResponse res)
{
    auto path = req.requestPath;
    string contentMD = readText("public/index");
    string content = filterMarkdown(contentMD);
    res.render!("basic.dt", content);
}

void handlePostsRequest(scope HTTPServerRequest req, scope HTTPServerResponse res)
{

    string[] content = getBlogFiles();
    res.render!("posts.dt", content);
}

int main()
{

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["::1", "127.0.0.1"];

    auto router = new URLRouter;

    router.get("/", &index);
    router.get("/blog/posts", &handlePostsRequest);
    router.get("/posts", &handlePostsRequest);
    router.get("/blog/*", &handleBlogRequest);
    router.get("/blog/", &handleBlogRequest);
    router.get("/blog", &handleBlogRequest);
    router.get("/index", &handleStandardRequest);
    router.get("/about", &handleStandardRequest);
    router.get("/contact", &handleStandardRequest);
    router.get("/projects", &handleStandardRequest);
    router.get("/speaking", &handleStandardRequest);
    router.get("/photography", &handleStandardRequest);

    router.get("/assets/*", serveStaticFiles("./public/"));

    auto listener = listenHTTP(settings, router);

    scope (exit)
        listener.stopListening();

    runApplication();

    return 0;
}
