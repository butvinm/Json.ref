# JSON encoder/decoder for Refal-05 (RFC 8259-compatible)

See the comments in [Json.ref](Json.ref) for the API reference and constraints.

## Usage

To use the library in your project, copy Json.ref and compile it alongside your own modules.

**Parse JSON and match its Refal representation:**

```refal
*FROM Json
$EXTERN Json-Parse;

$ENTRY Go {
  , <Json-Parse '{"string":"hello","number":42,"boolean":true,"null":null,"array":[1,2],"object":{}}'>
  : Success (Object
      ((String 'string') (String 'hello'))
      ((String 'number') (Decimal 42 (0)))
      ((String 'boolean') True)
      ((String 'null') Null)
      ((String 'array') (Array (Decimal 1 (0)) (Decimal 2 (0))))
      ((String 'object') (Object))
    )
  = <Prout 'Parsed as expected'>;
}
```

**Read JSON from a file and stringify it again:**

```refal
*FROM LibraryEx
$EXTERN ArgList, LoadFile;
*FROM Json
$EXTERN Json-Parse, Json-Stringify;

$ENTRY Go {
  , <ArgList> : {
    (e.Exe) (e.File)
      , <Json-Parse <UnwrapLines <LoadFile e.File>>>
      : {
        Success t.Json = <Prout <Json-Stringify t.Json>>;
        Fails s.Line s.Col e.Error
          = <Prout e.File ':' <Symb s.Line> ':' <Symb s.Col> ' ' e.Error>
            <Exit 2>;
      };
    (e.Exe) e.Args
      = <Prout 'usage: ' e.Exe ' <file.json>'>
        <Exit 1>;
  };
}

UnwrapLines {
  (e.Line) = e.Line;
  (e.Line) e.Lines = e.Line '\n' <UnwrapLines e.Lines>;
  = ;
}
```

## JSON query CLI

As a demonstration we implemented a JSON query cli tool like `jq`:

```bash
make refjq
./refjq '.' data.json
./refjq '.users[0].name' data.json
./refjq '.users[].name' data.json
cat data.json | ./refjq '.name'
```

## Tests

```bash
make test
```

- `make test-basic` compares the results of `Json-Parse`, both the parsed values and the parse errors, with the expected ones.
- `make test-stringify` compares the parsed and stringified back files with the expected ones.
- `make test-parsing` checks which files of JSONTestSuite are accepted and which are rejected.
- `make test-python-compat` checks that a file means the same to Python's `json` before and after a round trip through the parser, requires `python3`.

## License

[MIT](LICENSE)

The test data in `test/fixtures/JSONTestSuite` is copied from [JSONTestSuite](https://github.com/nst/JSONTestSuite) (commit `1ef36fa`), copyright (c) 2016 Nicolas Seriot, under its own MIT license, see [NOTICE](NOTICE).

## References

- [Refal-05](https://github.com/Mazdaywik/Refal-05)
- [JSONTestSuite](https://github.com/nst/JSONTestSuite)
- [RFC 8259 The JavaScript Object Notation (JSON) Data Interchange Format](https://www.rfc-editor.org/info/rfc8259/)
