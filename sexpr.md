# S-expressions

In this project, I'm using my own lisp-like format for serialization and data representation. Here is a small specification of the format.

There are two types of nodes, the atom and the list. The atoms are only strings, there are no other atomic types. An atom can be of two forms.

The first form is simple, and accept any character that is not a special character or whitespace (Special characters are `(`, `)`, `;` and `"`).

The other form is quoted, it starts with a `"` and ends with a `"`, it can contain any character except another quote (because it would indicate the end of the string), although it can contain escaped quotes. The escape sequences are a backslash (`\`) followed by any of these characters: `"` for a quote, `\` for a backslash, `n` for a line feed, `t` for a tabulation.

I like many other escape sequences from python and lua, like the `\xXX` for a byte or an ascii code, or `\u{XXXXXX}` for an Unicode character, or the `\z` for skipping whitespaces, but they are not implemented because they are not necessary for me yet.

A List node contains a sequence (possibly empty) of nodes, including other nested lists. the begining of a list is indicated by a `(` character, and the end is indicated by a `)` character (ignoring the ones used by internal lists).

Atoms and lists are separated by whitespace, that is a sequence of Unicode whitespace characters (for now my implementation only knows of the ascii space, newline and tab).

The comments are also counted as whitespace. a comment starts with `;` and extends to the end of the line, except if the semicolon is immediatly followed by a `(`, in that case it parses the list that would start there and turns it into a comment (note that `; (` is a line comment, not a list comment, note the space between the colon and the paren).

Some details of this format:

- Should the list comment count the quoted parentheses? My actual implementation does, but i think it shouldn't.
- What happens when a simple atom is followed by a quote without preceding whitespace (example: `abc"de"` instead of `abc "de"`? It could also be used to escape some complicated strings, but I think that should be an invalid atom. I don't know what my implementation does in this case, i think it starts a new separate atom.

# Syntax definition

```
node := atom | list

atom := simple | quoted
simple := simplechar { simplechar }
simplechar := Any except whitechar or special
special := '^' | ';' | '(' | ')'
whitechar := ' ' | '\n' | '\t'
quoted := '"' { (Any except '"') | '\' Any } '"'

list := '(' [node { whitespace node }] ')'
whitespace := { whitechar | linecomment | listcomment }
linecomment := ';' {Any except '\n'} '\n'
listcomment := ';' list

```
