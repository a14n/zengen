# v0.2.2 (2014-06-09)

## Features

- `@DefaultConstructor()`: generate a default constructor.
- `@Value()`: simplify the creation of value class.

# v0.2.1 (2014-06-07)

## Features

- `@Lazy()`: make field initialization lazy.

# v0.2.0 (2014-06-04)

Now a resolved-AST is used. This has been enforced for the implementation of `@Delegate`

- Add the optional named parameter `includePrivate` to `@ToString()` and `@EqualsAndHashCode`.
- Implementation of `operator==(o)` has been changed to use `identical` and `runtimeType`.

## Features

- `@Delegate`: generate methods from a getter type.


# v0.1.1 (2014-05-09)

- Add the optional named parameter `callSuper` to `@ToString()` and `@EqualsAndHashCode`.
- Add the optional named parameter `exclude` to `@ToString()` and `@EqualsAndHashCode`.


# v0.1.0 (2014-05-08)

Initial release available for public testing with `@ToString()` and `@EqualsAndHashCode`.

## Features

- `@ToString()`: generate the implementation of `String toString()`.
- `@EqualsAndHashCode()`: generate the implementation of `bool operator ==(o)` and `int get hashCode`.


# Semantic Version Conventions

http://semver.org/

- *Stable*:  All even numbered minor versions are considered API stable:
  i.e.: v1.0.x, v1.2.x, and so on.
- *Development*: All odd numbered minor versions are considered API unstable:
  i.e.: v0.9.x, v1.1.x, and so on.
