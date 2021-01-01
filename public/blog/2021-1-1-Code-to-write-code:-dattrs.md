# Code to write code: dattrs

This post is about the development of [dattrs](https://github.com/samathy/dattrs).

Earlier this week I started [working on a project](https://twitter.com/Samathy_Barratt/status/1344258796374413312) in [D lang](https://dlang.org)
to amalgamate my transaction history from my banks into one normalised CSV.

While writing out the skeletons of the functions and methods,
I found myself writing a class constructor that looks a bit like this:

    class transaction
    {
        this(string date, string time, string dest, string amount, string currency, string value)
        {
            this.date = date;
            this.time = time;
            this.dest = dest;
            this.amount = amount;
            this.currency = currency;
            this.value = value;
        }

        string date;
        string time;
        string dest;
        string amount;
        string currency;
        string value
    }

Now, I've used Python's [attrs](https://pypi.org/project/attrs) a lot at work 
to solve this specific problem. 
Particularly when writing mockish classes during tests when I need a fake class
that looks like a real one, but I only need to support a couple of features of
the real one.
You need to just make a constructor which only sets a bunch of member variables.

The attrs decorator generates a constructor like the one above for you, all you
have to do is tell it what the variables are. 
You can optionally describe stuff like defaults, and optional variables too.

    import attr

    @attr.s
    class wibble:
        a_string = attr.ib("hello")

    w = wibble("hi")
    assert w.a_string == True

Knowing that this exists for Python, [I
wondered](https://twitter.com/Samathy_Barratt/status/1344280722589298690) if I
could write something that did the same thing for D.

I already knew that [string mixins](https://dlang.org/spec/statement.html#mixin-statement) were a thing, 
and [template mixins](https://dlang.org/spec/template-mixin.html) also.
These combined with normal dlang templates, and maybe some reflection 
should surely allow me to generate the boilerplate constructor code
at compile time simply by passing _something_ the names and types of the variables I wanted to create.

Tempalate mixins allow you to write actual declarations that you can imagine getting copy-pasted into 
the instatiation location of the mixin. The body of a template mixin can only
be a declaration.

    mixin template wibble(T, T value)
    {
        T wibble = value;
    }

    class fibble
    {
        mixin wibble!(int, 10);
    }


Is the same as:

    class fibble
    {
        int wibble = 10;
    }

String mixins are a clever way to bring literal strings into your source code.
The the compiler sees a string mixin, it just takes the string and treats it as if you wrote it straight into the source file.
Importantly, you can _generate_ strings to be mixed in at compile time, then mix them in slightly later in the compilation process. 

    string constructor = "this(){}";

    class fibble
    {
        mixin(constructor);
    }

Is the same as:

    class fibble
    {
        this(){}
    }


<hr>
I started by investigating template mixins some more for my application, knowing I could use them to pass in some parameters, 
and generate a constructor and member variable declarations.

Something like this:

    mixin template define(string[] names, ARGS...)
    {

    }

Here, `ARGS` is a variadic template paramater.
This means that the mixin template `define` takes an array of strings into `names`, followed by one or more types inserted into an array/iterable like object called ARGS. 
( `ARGS` is actually an [AliasSeq](https://dlang.org/library/std/meta/alias_seq.html), a compile time only iterable type.).

My intention is to use the `names` as a list of what we want to call the class'
member variables, and the ARGS as a list of types of those variables.

I could have used another array of strings for the types and used string mixins
to insert them later, but this is D, so we're going to use actual types.

Note, that this code is a proof-of-concept, so I'm not checking anywhere that `names.length == ARGS.length`. 
I should probably add that into some [template constraints](https://dlang.org/concepts.html).

We have our template mixin, lets work out how to actually generate the `this` constructor.

If I wanted to just define a constructor followed by defining our member variables, I can do that like so:

    mixin template define(string[] names, ARGS...)
    {
        this()
        {
        //constructor body
        }

        static foreach(int i, t; ARGS)
        {
            mixin (t.stringof ~ " " ~ names[i]~";");
        }
    }

As you can see, what you write in a mixin template must be actual, compilable code. 
My declaration of a `this` constructor has no place in a template, they only work in classes.
Yet, I havent had to enclose the code in a string or anything. Just write the code like I would normally.

Here, we're using a compile-time foreach loop to add the string of the form
"{typename} {variable name};" to the source.

Calling the mixin template like so gives us what we want.

    class wibble
    {
        mixin define!(["val1"], string]);
    }

    class wibble
    {
        this()
        {
        }
       
        string val1; 
    }

The next step is generating a 'this' constructor which takes all the paramameters we need it to take.

We can't use a `static foreach` to generate the parameters one-by-one
_after_ defining the function, because the source-code added by just writing `this(` is
evaluated before the `static foreach` is evaluated. 
Meaning that the compiler sees the string `this(`, then sees `static foreach`
and complains about the foreach being unexpected. 

    mixin template define(string[] names, ARGS...)
    {
        this( //Nope, this gets added as real source and is an unfinished declaration.
        static foreach(int i, t; ARGS)
        {
            mixin(t.stringof~" "~names[i]~";")
        }
        ) //Also makes the compiler upset.
    }


We also can't generate the `this` declaration with it's parameters all at once using a string mixin either.
I'd like to be able to use Python-like syntax like the following to do this in one line, but I can't.

    mixin("this(".join([t.stringof~" "~names[i] for i, t in enumerate(ARGS)]) ~ ")");

Because I can't do magic list comprehensions in one line, I'd have to do this instead:

    mixin template define(string names[], ARGS...)
    {
        mixin("this(");
        static foreach(int i, t; ARGS)
        {
            mixin(t.stringof~" "~names[i]~";")
        }
        mixin(")");
    }

However, that also doesnt work for exactly the same reason as the other `foreach` method discussed a moment ago.
Here the string mixins get turned into real code, _then_ evaluated by the
compiler, all before the `static foreach` gets evaluated. So, same problem, to
the compiler the `this(` is followed by `static foreach...` which doesnt make
sense.


Instead, we have to write a regular template, which generates a string of comma
separate parameters from a given set of variable names and types.
Then, we can pass that template's results straight into our string mixin to generate the entire declaration of `this` all at once.

    /*
    when called with this_args!(["val1", "val2"], string, string) this template returns the string
    "string val1, string val2"
    */

    template this_args(string[]names, ARGS...)
    {
        static string this_args() //Compile time executable function
        {
            string this_args;
            static foreach(int i, t; ARGS)
            {
                this_args ~= t.stringof~" "~names[i]~","; //Append a new argument to the string every time
            }
            return this_args;
        }
    }

    mixin template define(string[] names, ARGS...)
    {
        //define an empty constructor
        mixin("this("~this_args!(names, ARGS)~"){}"); //Call the template and generate the argument list

        //define the class member variables
        static foreach(int i, t; ARGS)
        {
            mixin(t," "~names[i]~";");
        }
    }

The magic `this_args` templated function runs at compile time, because we pass
in all the parameters ( `names` and `ARGS` ) at as template params the D compiler
already _knows_ what it needs to know to run it at compile time.
We can also run that function at runtime if we'd like though!

Finally, we can generate the body of the constructor function with a similar template. 
One which generates a string of assignements to our class members.

    template this_body(string[] names, ARGS...)
    {
        static string this_body()
        {
            string this_body;
            static foreach(int i, t; ARGS)
            {
                this_body = "this."~names[i]~" = "~names[i]~";";
            }
            return this_body;
        }
    }

    template this_args(string[]names, ARGS...)
    {
        static string this_args()
        {
            string this_args;
            static foreach(int i, t; ARGS)
            {
                this_args ~= t.stringof~" "~names[i]~",";
            }
            return this_args;
        }
    }


    mixin template define(string[] names, ARGS...)
    {
        mixin("this("~this_args!(names, ARGS)~"){"~this_body!(names, ARGS)~"}");

        static foreach(int i, t; ARGS)
        {
            mixin(t," "~names[i]~";");
        }
    }


At last, we have a mixin template that we can use inside a class definition to write out boilerplate for us.

    class wibble
    {
        mixin define!(["val1"], string)
    }


Will generate something like this, at compile time, with zero runtime cost.

    class wibble
    {

        this(string val1)
        {
            this.val1 = val1;
        }

        string val1;
    }


*Hazzah* That replicates my most common use-case of Python's 'attrs' but in D!

_dattrs_ is available on [code.dlang.org](https://code.dlang.org/packages/dattrs).

