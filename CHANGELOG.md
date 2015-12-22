# v0.3.2 (2015-12-22)

Update [quiver](https://pub.dartlang.org/packages/quiver) version range.

See https://github.com/a14n/zengen/milestones/0.3.2

# v0.3.1 (2015-12-15)

## Bug fixes

See https://github.com/a14n/zengen/milestones/0.3.1

# v0.3.0 (2015-10-08)

Brand new implementation based on [source_gen](https://pub.dartlang.org/packages/source_gen).

# v0.2.8 (2014-12-10)

## Bug fixes

- Getting rid of `export` ([#19](https://github.com/a14n/zengen/issues/19)).

# v0.2.7 (2014-06-22)

## Features

- `@Cached()`: allows to cache results of methods ([#14](https://github.com/a14n/zengen/issues/14)).

# v0.2.6 (2014-06-17)

## Features

- `@DefaultConstructor()` and `@Value()` now accept a `useConst` to generate a const constructor ([#17](https://github.com/a14n/zengen/issues/17)).

# v0.2.5 (2014-06-16)

## Bug Fixes

- @DefaultConstructor() doesn't create `const` for now.

# v0.2.4 (2014-06-14)

## Bug Fixes

- @Implementation() doesn't handle field on interface ([#16](https://github.com/a14n/zengen/issues/16)).

# v0.2.3 (2014-06-12)

## Features

- `@Implementation()`: implementation of all abstract methods.

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
