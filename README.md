# JSON encoder/decoder for Refal-05

## Example

The Refal-05 compiler is included as a submodule and is built from source on the first `make`, so only a C compiler is required.

Use the following command to build and run `example.ref`:

```bash
make example && ./example
```

## Tests

```bash
make test
```

## License

[MIT](LICENSE)

The test data in `test/test_parsing` and `test/test_transform` is copied from [JSONTestSuite](https://github.com/nst/JSONTestSuite) (commit `1ef36fa`), copyright (c) 2016 Nicolas Seriot, under its own MIT license, see [NOTICE](NOTICE).

## References

- [Refal-05](https://github.com/Mazdaywik/Refal-05)
- [JSONTestSuite](https://github.com/nst/JSONTestSuite)
- [ECMA-404 The JSON data interchange syntax](https://ecma-international.org/publications-and-standards/standards/ecma-404/)
