package YAML::Yaml2Html;

use 5.008003;
use YAML;
use strict;
use warnings;

require Exporter;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw();
our @EXPORT    = qw();

our $VERSION = '0.5';

my ( %level, %toc, %head, %title, %category, %body, %dictionary );

sub new
{
   my $self = bless [] => shift;
   my $doc  = shift;
   
   $self->toc  = [];
   $self->body = [];
   
   $self->loadFile( $doc ) if $doc;
   return $self;
}

sub DESTROY
{
   my $sref = 0+shift;
   delete $level{$sref},
          $toc{$sref},
          $head{$sref},
          $title{$sref},
          $category{$sref},
          $body{$sref},
          $dictionary{$sref};
}

sub toFile
{
	 my $self = shift;
	 my $file = shift;
	 
	 $file =~ s/\.\w+$//; # out with the old extension
	 $file .= '.html';    # ...in with the new
	 
	 open OUT, ">$file" || die "ERROR: Cannot open $file.\n";
	 print OUT $self->toString();
	 close OUT;
}

sub toString
{
	 my $self = shift;
	 my $toc   = join( "\n", @{$self->toc()} );
	 my $category = $self->category();
	 my $title = $self->title();
	 my $head  = $self->head();
	 my $body  = join( "\n", @{$self->body()} );
	 my $stamp = (localtime time) . ' '. __PACKAGE__ . ' v' . $VERSION;
   return<<HTML;
<html>
<head>
<title>$title</title>
<STYLE TYPE="text/css">
<!--
.rightalign {text-align:right}
-->
$head
</STYLE>
</head>
<body>
<p class="rightalign">
   <font size=+3 color=red><i>$category</i></font><br>
   <font size=+2><i>$title</i></font>
</p>
<hr color=lightgrey>
<a name=toc><font size=+1>Table Of Contents</font></a>
$toc
<hr color=lightgrey>
$body
<hr color=lightgrey>
<p class="rightalign">
  <font size=-1 color=grey><i>$stamp</i></font>
</p>
</body>
HTML
}

sub level      :lvalue { $level      {+shift}; }
sub toc        :lvalue { $toc        {+shift}; }
sub title      :lvalue { $title      {+shift}; }
sub category   :lvalue { $category   {+shift}; }
sub head       :lvalue { $head       {+shift}; }
sub body       :lvalue { $body       {+shift}; }
sub dictionary :lvalue { $dictionary {+shift}; }

   
sub loadFile
{
	 my $self  = shift;
	 my $doc   = shift;
   my $text  = $self->readFile( $doc );
   $self->loadText( $text );
}

sub loadText
{
   my $self = shift;
   my $text = shift;
   my $yaml = YAML::Load( $text );

   $self->processContent( $yaml );   
}

sub readFile  # ugly kludge
{
	 my $self = shift;
   my $doc  = shift;
   my @yamlsrc;
   open( IN, $doc ) || die "ERROR: Cannot open file $doc\n";
   foreach (<IN>)
   {
   	  next unless /^-{3} / .. /^\.{3} /;
#   	  print;
      push @yamlsrc, $_;
   }
   close IN;
   pop @yamlsrc if $yamlsrc[-1] =~ /^\.{3} /; # remove final EOD
   
   my $yamlsrc = join '', @yamlsrc;
   return $yamlsrc;
}

sub processContent
{
   my $self = shift;
   my $yaml = shift;

   $self->level = 1;   
   $self->category = $yaml->{category} || $yaml->{Category} || '';
   $self->title = $yaml->{title} || $yaml->{Title} || '';
   $self->head  = $yaml->{head}  || $yaml->{Head}  || '';
   $self->head .= $self->processCss( $yaml->{css} );
   
   $self->dictionary = $yaml->{dictionary} || $yaml->{Dictionary};
   $self->dictionary = $self->processDictionary() if $self->dictionary;
   
   my $body = $yaml->{body} || $yaml->{Body};
   $self->processRef( $body );
}

sub processDictionary
{
	 my $self     = shift;
	 
	 my @ac = ();
	 foreach my $key (keys %{$self->dictionary})	 
	 {
	    my $value = $self->dictionary->{$key};
	    $value =~ s/\"/\\\\/g;
	    push @ac, "s|$key|<acronym title=\"$value\">$key</acronym>|g";
	 }
	 
	 return \@ac;
}

sub processCss
{
	 my $self = shift;
	 my $css  = shift;
	 
	 return '' unless $css;
	 return<<CSS;
   <STYLE TYPE="text/css" TITLE="currentStyle">
      \@import "$css";
   </style>
CSS
}

sub processRef
{
	 my $self    = shift;
   my $yref    = shift;
   my $count   = shift;
   
   $self->processMapref($yref, $count)    if ref($yref) eq 'HASH';
   $self->processArrayref($yref, $count)  if ref($yref) eq 'ARRAY';
   $self->processString($yref, $count)    if ref($yref) eq ''; # just a string!
}

sub processMapref
{
	 my $self    = shift;
	 my $mapref  = shift;
	 my $count   = shift;
   my $indent  = '  ' x $self->level;	 

   foreach my $key (sort keys %$mapref)
   {
   	  my $level = $self->level;
   	  my $val = $mapref->{$key};
   	  push @{$self->toc},  "$indent<li><a href='#$key'>$key</a></li>";
   	  push @{$self->body}, "$indent<div id=\"d$count\"><a name='$key'><h$level>$key</h$level></a></div>";
      $self->level++;    
      $self->processRef( $val, $count+1 );
      $self->level--;
   }
}

sub processArrayref
{
	 my $self    = shift;
   my $aryref  = shift;
	 my $count   = shift;
   my $indent  = '  ' x $self->level;
   
	 push @{$self->toc},  "$indent<ol>";
	 push @{$self->body}, "$indent<font size=-1><a href=#toc>[Table of Contents]</a></font><br>\n$indent<ul>";
	 
	 my $c2 = 0;
   foreach my $key (@$aryref)
   {
   	  my $val = $key;
      $self->processRef( $val, $c2 );
      $c2++;
   }
   push @{$self->body}, "$indent</ul>";
   push @{$self->toc}, "$indent</ol>";
}

sub processString
{
	 my $self    = shift;
   my $str     = shift;
	 my $count   = shift;
   my $indent  = '  ' x $self->level;
   my @lines   = split( "\n", $str );
   
   my $c = 0;
   
   if ( $self->dictionary )
   {
      foreach(@lines)
      {
         foreach my $ac (@{$self->dictionary})
         {
            eval($ac);
         }
      }
   }
   
   foreach(@lines)
   {
   	  next if /<pre>/ .. /<\/pre>/;
   	  
   	  if ( /\w/ )
   	  {
         $_ = "$indent<p class=\"p$c\">$_</p>";
         $c++;
   	  }   	  
   }
   
   foreach(@lines)
   {
   	  next unless /<pre>/ .. /<\/pre>/;
   	  $_ = $indent . $_ ; # . "\n";
   }
   
   push @{$self->body}, @lines;
}
1;

__END__
--- 
title: yaml2html.pm
category: category-info
css: css-info
dictionary:
   YAML: YAML Ain't Markup Language
   POD: Perl's "Plain Old Documentation" format
head: |
   <script>
   var foo = 0;
   </script>
body:
   - yaml2html:
      - Author: Robert Eaglestone
   
   - Example: |
        <pre> 
        use YAML::Yaml2Html;
        
        my $y2h = new YAML::Yaml2Html( $my_document );      
        print $y2h->toString();
        
        my $y2h = new YAML::Yaml2Html();
        $y2h->loadFile( $y2h );
        print $y2h->toString();
        
        my $y2h = new YAML::Yaml2Html();
        $y2h->loadText( "---\ntitle: This is just a test\n..." );
        $y2h->toFile( "myfile" ); 
        # module will auto-append '.html' if it's not already there.
        </pre>
   
   - Detail:
      - Purpose: >
         This is a YAML parser which takes a specialized YAML document
         and emits primitive HTML.
      
      - Origins: >
         I recently learned POD.  Immediately, I was taken by
         its simplicity.  It's so much easier to use than HTML,
         I even began writing simple HTML documents -- which had
         nothing to do with Perl -- with POD, then using pod2html 
         to convert to a webbable format.
         
         After doing this for awhile, I started to realize that
         POD was simply a heirarchical markup notation... just the 
         kind of thing that YAML is good for.  Well, being rather 
         lazy when it comes to using two tools where a single tool
         will work fine, I decided to write a proof-of-concept
         Perl structure parser that could output HTML... a back-end
         to YAML, in a way.
         
      - How to use it: 
         - Assumptions: I assume you already know the basics of YAML.
         
         - Root-level keys: |
         
            Everything is optional.
            
            <b>category:</b> document super-title or category title
            <b>title:</b> title text goes here      
            <b>head:</b>  head text goes here (like Javascript)
            <b>css:</b>   name of a CSS file goes here (this is a convenience tag)
            <b>dictionary:</b> a map of acronyms to their definitions
            <b>body:</b>  list of chapters
         
         - Chapters: >
            Since hashtables are unordered, I find that using arrays
            in the document body ensures that my sections come out in the 
            order I entered them.  So all of the body sections, including the 
            root "Chapters", are lists.  List items themselves are maps 
            or hashtables containing either (1) another list, or (2) text.

            The leaf nodes, which necessarily are strings, are mapped
            to their section titles.  Refer to this example to see
            what I mean.
         
         - Dictionary: >
            This is a very handy tag.  This is a mapping of acronyms used in the
            document with their definitions.  This module performs a global text
            replacement, with the acronym replaced by the HTML fragment:
            < acronym title="whatever" >ACRONYM< / acronym >
                           
      - What this script does with the text: >
            This script builds a table of contents and a body.
            
            Sections are titled using < h1 >, < h2 >...< hn >, according
            to their subordinate level.  They're also indented: the table
            of contents is indented using an Ordered (Numbered) List, and 
            the body is indented using < div id="d##"> tags, where ## is
            the division number within that level.  Paragraphs within 
            text bodies are divided with < p class="p##"> tags, where ##
            is the paragraph number within that text.
            
            < br > tags are added before newline characters in the body text,
            except when the text is inside < pre >...< /pre > tags, in which
            case it's left alone.
... 

=head1 NAME

YAML::Yaml2Html - Builds an HTML page from a YAML-based document.

=head1 SYNOPSIS

        use YAML::Yaml2Html;
        
        my $y2h = new YAML::Yaml2Html( $my_document );      
        print $y2h->toString();
        
        OR
        
        my $y2h = new YAML::Yaml2Html();
        $y2h->loadFile( $y2h );
        print $y2h->toString();
        
        OR
        
        my $y2h = new YAML::Yaml2Html();
        $y2h->loadText( "---\ntitle: This is just a test\n..." );
        $y2h->toFile( "myfile" ); 
        # module will auto-append '.html' if it's not already there.

=head1 DESCRIPTION

=over 3

This uses the YAML parser to convert a specialized YAML document
into an HTML page.

I recently learned POD.  Immediately, I was taken by
its simplicity.  It's so much easier to use than HTML,
I even began writing simple HTML documents -- which had
nothing to do with Perl -- with POD, then using pod2html 
to convert to a webbable format.

After doing this for awhile, I started to realize that
POD was simply shorthand for heirarchical text... just the 
kind of thing that YAML is good for.  Well, being rather 
lazy when it comes to using two tools where a single tool
will work fine, I decided to write a proof-of-concept
Perl structure parser that could output HTML... a back-end
to YAML, in a way.

=back

=over 3

Root-level keys (Everything is optional):

   category: document super-title or category title
   
   title: title text goes here      
   
   head: head text goes here (like Javascript)
   
   css: name of a CSS file goes here (this is a convenience tag)
   
   dictionary: a map of acronyms to their definitions
   
      This is a very handy tag.  This is a mapping of acronyms used in the
      document with their definitions.  This module performs a global text
      replacement, with the acronym replaced by the HTML fragment:
      < acronym title="whatever" >ACRONYM< / acronym >
   
   body: list of chapters
   
      Since hashtables are unordered, I find that using arrays
      in the document body ensures that my sections come out in the 
      order I entered them.  So all of the body sections, including the 
      root "Chapters", are lists.  List items themselves are maps 
      or hashtables containing either (1) another list, or (2) text.
      
      The leaf nodes, which necessarily are strings, are mapped
      to their section titles.  Refer to this example to see
      what I mean.

=back

=over 3

This script builds a table of contents and a body.

Sections are titled using < h1 >, < h2 >...< hn >, according
to their subordinate level.  They're also indented: the table
of contents is indented using an Ordered (Numbered) List, and 
the body is indented using < div id="d##"> tags, where ## is
the division number within that level.  Paragraphs within 
text bodies are divided with < p class="p##"> tags, where ##
is the paragraph number within that text.

< br > tags are added before newline characters in the body text,
except when the text is inside < pre >...< /pre > tags, in which
case it's left alone.

=back

=head1 AUTHOR

Robert Eaglestone

=head1 COPYRIGHT

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AVAILABILITY

The latest version of this library is likely to be available from CPAN.

=cut

