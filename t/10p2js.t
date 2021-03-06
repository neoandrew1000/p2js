use Test::More tests => 68;

BEGIN { use_ok('IWL::P2JS'); push @INC, "./t"; }
use Foo;

my $p = IWL::P2JS->new(globalScope => 1);

sub test_general {
    is($p->convert(sub {}), '');
    is($p->convert(sub {my $a = 12}), "var a = 12;");
    is($p->convert(sub {my $foo = "bar"}), "var foo = 'bar';");
    is($p->convert(sub {my @a = (1,2,3)}), "var a = [1, 2, 3];");
    is($p->convert(sub {my $a = [1,2,3]}), "var a = [1, 2, 3];");
    is($p->convert(sub {my %a = (a => 1)}), "var a = {'a': 1};");
    is($p->convert(sub {my $a = {a => 1}}), 'var a = {"a": 1};');
    is($p->convert(sub {my ($a, $b) = (a => 1)}), "var a = 'a', b = 1;");

    is($p->convert(sub {my $a = 12; my $b = $a ? 42 : ''}), "var a = 12;var b = a ? 42 : '';");
    is($p->convert(sub {my $a = 12; my $b = 42 if $a}), "var a = 12;if ( a) var b = 42;");
    is($p->convert(sub {my $a = 12; my $b = 42 unless $a}), "var a = 12;if (!( a)) var b = 42;");
    is($p->convert(sub {my $a = 12; my $b = 42 while $a}), "var a = 12;while ( a) var b = 42;");
    is($p->convert(sub {my $a = 12; my $b = 42 until $a}), "var a = 12;while (!( a)) var b = 42;");

    is($p->convert(sub {my $a = 12; window::alert($a)}), "var a = 12;window.alert(a);");
    is($p->convert(sub {my $a = 12; window->alert($a)}), "var a = 12;window.alert(a);");
    is($p->convert(sub {my $a = 12; alert($a)}), "var a = 12;alert(a);");
    is($p->convert(sub {my $a = 12; Math::max($a, 5)}), "var a = 12;Math.max(a, 5);");
    is($p->convert(sub {my $url = 'foo.pl'; my $ajax = Ajax::Request->new($url, {parameters => {a => 1}}); $ajax->abort}), q|var url = 'foo.pl';var ajax = new Ajax.Request(url, {"parameters": {"a": 1}});ajax.abort();|);
    is($p->convert(sub {my $url = 'foo.pl'; my $ajax = Ajax::Request->new($url, {array => [1, 'foo']}); $ajax->abort}), q|var url = 'foo.pl';var ajax = new Ajax.Request(url, {"array": [1, "foo"]});ajax.abort();|);
    is($p->convert(sub {my $foo = "document"->getElementById('foo')->down()->next(2)->down('.class'); $foo->remove();}), q|var foo = document.getElementById('foo').down().next(2).down('.class');foo.remove();|);
    is($p->convert(sub {my $foo = document::getElementById('foo')->down()->next(2)->down('.class'); $foo->remove();}), q|var foo = document.getElementById('foo').down().next(2).down('.class');foo.remove();|);

    is($p->convert(sub {my $a = 12; if ($a) {my $b = $a / 2}}), "var a = 12;if (a) {var b = a / 2;}");
    is($p->convert(sub {my $a = 12; unless ($a) {my $b = $a / 2}}), "var a = 12;if (!(a)) {var b = a / 2;}");
    is($p->convert(sub {my $a = 12; while ($a) {my $b = $a / 2}}), "var a = 12;while (a) {var b = a / 2;}");
    is($p->convert(sub {my $a = 12; until ($a) {my $b = $a / 2}}), "var a = 12;while (!(a)) {var b = a / 2;}");
    is($p->convert(sub {my $a = 12; for (my $i = 0; $i < 100; ++$i) {my $b = $a / 2}}), "var a = 12;for (var i = 0; i < 100; ++i) {var b = a / 2;}");
    is($p->convert(sub {my $a = 12; for (1 .. 100) {my $b = $a / 2}}), "var a = 12;for (var _ = 1; _ < 101; ++_) {var b = a / 2;}");
    is($p->convert(sub {my $a = 12; for (1,6,21,4) {my $b = $a / 2}}), q|var a = 12;var _$ = [1, 6, 21, 4];for (var i = 0, _ = _$[0]; i < _$.length; _ = _$[++i]) {var b = a / 2;}delete _$;|);
    is($p->convert(sub {for (['perl', 10], ['module', 20]) {my $b = $_->[0] . $_->[1]}}), q|var _$ = [["perl", 10], ["module", 20]];for (var i = 0, _ = _$[0]; i < _$.length; _ = _$[++i]) {var b = _[0] + _[1];}delete _$;|);
    is($p->convert(sub {my %a = (a => 1, b => 2); for (keys %a) {my $b = $a{$_}}}), q|var a = {'a': 1, 'b': 2};for (var _ in a) {var b = a[_];}|);
    is($p->convert(sub {my $v = $_ foreach ([1,2])}), 'var _$ = [[1, 2]];for (var i = 0, _ = _$[0]; i < _$.length; _ = _$[++i]) var v = _;delete _$;');
    is($p->convert(sub {my $v = $_ foreach ([1,2], [3,4])}), 'var _$ = [[1, 2], [3, 4]];for (var i = 0, _ = _$[0]; i < _$.length; _ = _$[++i]) var v = _;delete _$;');

    is($p->convert(sub {my $a = sub {return 1}}), q|var a = function() {return 1;};|);
    is($p->convert(sub {my $a = sub {my ($b, $c, $d) = @_; return 1}}), q|var a = function(b, c, d) {return 1;};|);
}

sub test_lexical {
    my $a = 42;
    my $b = 'foo';
    my @c = (1,2,3);
    my %d = (a => 1, b => $a);
    my $e = [7,8,9];
    my $f = {c => $b , d => $e};
    my $g = Foo->new;
    my @h = ([1, 2], [3, 4]);

    is($p->convert(sub {my $v = $a}), 'var v = 42;');
    is($p->convert(sub {my $v = $b}), 'var v = "foo";');
    is($p->convert(sub {my $v = @c}), 'var v = [1, 2, 3];');
    is($p->convert(sub {my $v = %d}), 'var v = {"a": 1, "b": 42};');
    is($p->convert(sub {my $v = $e}), 'var v = [7, 8, 9];');
    is($p->convert(sub {my $v = $f}), 'var v = {"c": "foo", "d": [7, 8, 9]};');
    is($p->convert(sub {my $v = $g->printJS}), 'var v = "Hello JS.";');
    is($p->convert(sub {my $v = $g->overloaded}), 'var v = 1;');
    is($p->convert(sub {my $v = $g->printArgs(qw(abs 12 42f))}), 'var v = "abs, 12, 42f";');
    is($p->convert(sub {my $v = $g->dumpArgs({a => 1}, 42)}), 'var v = "[{\'a\' => 1},42]";');
    is($p->convert(sub {my $v = $g->this->overloaded}), 'var v = 1;');
    is($p->convert(sub {my $v = $g->{prop1}}), 'var v = 42;');
    is($p->convert(sub {my $v = $g->this->{prop1}}), 'var v = 42;');
    is($p->convert(sub {my $v = $g->{prop2}[0]}), 'var v = "am";');
    is($p->convert(sub {my $v = Foo->printJS}), 'var v = "Hello JS.";');
    is($p->convert(sub {my $v = Foo::printJS}), 'var v = "Hello JS.";');
    is($p->convert(sub {my $v = Foo->printArgs(qw(abs 12 42f))}), 'var v = "abs, 12, 42f";');
    is($p->convert(sub {my $v = Foo::printArgs($a, $b, 'abs')}), 'var v = "42, foo, abs";');
    is($p->convert(sub {my $v = Foo->printArgs($a, $b, 'abs')}), 'var v = "42, foo, abs";');
    is($p->convert(sub {my $v = $_ foreach 1 .. $a}), 'for (var _ = 1; _ < 43; ++_) var v = _;');
    is($p->convert(sub {my $v = $_ foreach (@c, $a)}), 'var _$ = [1, 2, 3, 42];for (var i = 0, _ = _$[0]; i < _$.length; _ = _$[++i]) var v = _;delete _$;');
    is($p->convert(sub {my $v = $_ foreach @h}), 'var _$ = [[1, 2], [3, 4]];for (var i = 0, _ = _$[0]; i < _$.length; _ = _$[++i]) var v = _;delete _$;');
    is($p->convert(sub {my $v = $a if $a}), 'if ( 42) var v = 42;');
    is($p->convert(sub {while ($a) { my $v = $b}}), 'while (42) {var v = "foo";}');
}

sub test_real {
    is($p->convert(sub {IWL::Status::display('Stock button loaded')}), "IWL.Status.display('Stock button loaded');");
    is($p->convert(sub {IWL::Status::display->bind($this, 'Completed')}), "IWL.Status.display.bind(this, 'Completed');");
    my $message = "five";
    is($p->convert(sub {IWL::Status::display("Icon $message was selected")}), "IWL.Status.display('Icon ' + \"five\" + ' was selected');");
    is($p->convert(sub {IWL::Status::display("Don't panic")}), "IWL.Status.display('Don\\'t panic');");
    is($p->convert(sub {IWL::Status::display($this->getLabel . ' selected.')}), "IWL.Status.display(this.getLabel() + ' selected.');");
    is($p->convert(sub {IWL::Status::display($arguments->[0]{data}{text})}), "IWL.Status.display(arguments[0].data.text);");
    my $container = Foo->new;
    my $path = '/foo/bar/';
    is($p->convert(sub {my $css = {background => "url(${path}perl.jpg) no-repeat"}}), q|var css = {"background": "url(" + "/foo/bar/" + "perl.jpg) no-repeat"};|);
    is($p->convert(sub {Effect::Morph->new($this, {afterFinish => $this->{writeAttribute}->bind($this, {src => '/skin/images/perl2.jpg'})})}),
        q|new Effect.Morph(this, {"afterFinish": this.writeAttribute.bind(this, {"src": "/skin/images/perl2.jpg"})});|);
    is($p->convert(sub {$this->signalConnect(click => (sub {$this->{__value} = $arguments[0]})->bind($this, 1))}),
        q|this.signalConnect('click', function() {this.__value = arguments[0];}.bind(this, 1));|);
}

test_general;
test_lexical;
test_real;
