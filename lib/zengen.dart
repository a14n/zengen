// Copyright (c) 2014, Alexandre Ardhuin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library zengen;

import 'dart:async';
import 'dart:collection';

import 'package:collection/equality.dart' show ListEquality, MapEquality;

import 'package:quiver/core.dart' as quiver show hashObjects;

int hashObjects(Iterable objects) => quiver.hashObjects(objects);

/// Marker on generated elements
const generated = null;

/// Annotation to use on classes to generate the `toString()` method.
///
/// By default the public getter are used to generate the code.
/// You can customize the generated code with [callSuper], [exclude] and [includePrivate].
class ToString {
  /// Indicates that the generated code has to use `super.toString()`.
  final bool callSuper;
  /// Specifies the list of Symbol to not use in the generated code.
  final List<Symbol> exclude;
  /// Indicates that the generated code has to use also private members.
  final bool includePrivate;

  const ToString({this.callSuper, this.exclude, this.includePrivate});
}

/// Annotation to use on classes to generate the `int get hashCode` getter and the `==` operator.
///
/// By default the public getter are used to generate the code.
/// You can customize the generated code with [callSuper], [exclude] and [includePrivate].
class EqualsAndHashCode {
  /// Indicates that the generated code has to use the parent `hashCode` and `==`.
  final bool callSuper;
  /// Specifies the list of Symbol to not use in the generated code.
  final List<Symbol> exclude;
  /// Indicates that the generated code has to use also private members.
  final bool includePrivate;

  const EqualsAndHashCode({this.callSuper, this.exclude, this.includePrivate});
}

/// Annotation to use on field/getter to add to the enclosing class all the public methods available on the type of the field/getter.
///
/// By default the public accessors and methods are used to generate the code.
/// You can customize the generated code with [exclude].
class Delegate {
  /// Specifies the list of Symbol to not use in the generated code.
  final List<Symbol> exclude;

  const Delegate({this.exclude});
}

/// Annotation to use on fields to make them lazy computed.
class Lazy {
  const Lazy();
}

/// Annotation to use on classes to create a default constructor with uninitialized final fields.
class DefaultConstructor {
  /** The indicator to use when a const construtor have to be generated. */
  final bool useConst;

  const DefaultConstructor({this.useConst});
}

/// Annotation to use on classes to make them immutable const classes.
class Value {
  /** The indicator to use when a const construtor have to be generated. */
  final bool useConst;

  const Value({this.useConst});
}

/// Annotation to use on a method accepting a [StringInvocation] parameter. This method will be called for every abstract members of the class.
class Implementation {
  const Implementation();
}
/// Same structure as [Invocation] but with [String] instead of [Symbol].
class StringInvocation {
  /** The name of the invoked member. */
  final String memberName;

  /**
   * An unmodifiable view of the positional arguments of the call.
   *
   * If the member is a getter, the positional arguments is empty.
   */
  final List positionalArguments;

  /**
   * An unmodifiable view of the named arguments of the call.
   *
   * If the member is a getter, setter or operator, the named arguments
   * is empty.
   */
  final Map<String, dynamic> namedArguments;

  /** Whether the invocation was a method call. */
  final bool isMethod;

  /**
   * Whether the invocation was a getter call.
   * If so, both types of arguments is empty.
   */
  final bool isGetter;

  /**
   * Whether the invocation was a setter call.
   *
   * If so, [positionalArguments] has exactly one positonal argument,
   * and [namedArguments] is empty.
   */
  final bool isSetter;

  StringInvocation(this.memberName, {this.isMethod: false, this.isGetter:
      false, this.isSetter: false, this.positionalArguments: const
      [], this.namedArguments: const {}});

  /** Whether the invocation was a getter or a setter call. */
  bool get isAccessor => isGetter || isSetter;

  @override String toString() => "StringInvocation(memberName=$memberName, "
      "positionalArguments=$positionalArguments, namedArguments=$namedArguments, "
      "isMethod=$isMethod, isGetter=$isGetter, isSetter=$isSetter, "
      "isAccessor=$isAccessor)";
}

/// Annotation to use on methods to cache the result. You can customize the [Cache] used by implementing `Cache _createCache(Symbol methodName, Function compute)`.
class Cached {
  const Cached();
}
/// Class used to call for the computed value.
abstract class Cache<T> {
  factory Cache(Function compute) => new NoLimitCache(compute);

  getValue(List positionalArguments, [Map<Symbol, dynamic> namedArguments]);
}
/// An implementation of [Cache] that does not cache anything and always compute the result.
class NoCache implements Cache {
  final Function _compute;
  NoCache(this._compute);

  getValue(List positionalArguments, [Map<Symbol, dynamic> namedArguments]) =>
      Function.apply(_compute, positionalArguments, namedArguments);
}
/// A key containing the parameters used to call a method.
class MethodArguments {
  static const _listEquality = const ListEquality();
  static const _mapEquality = const MapEquality();

  final List positionalArguments;
  final Map<Symbol, dynamic> namedArguments;

  MethodArguments(this.positionalArguments, [this.namedArguments = const {}]);

  @override int get hashCode => _listEquality.hash([_listEquality.hash(
      positionalArguments), _mapEquality.hash(namedArguments)]);
  @override bool operator ==(o) => identical(this, o) || runtimeType ==
      o.runtimeType && _listEquality.equals(positionalArguments, o.positionalArguments
      ) && _mapEquality.equals(namedArguments, o.namedArguments);
}
/// An implementation of [Cache] that computes the result only once and always returns the same result.
class NoLimitCache implements Cache {
  final Function _compute;
  final values = new HashMap<MethodArguments, dynamic>();
  NoLimitCache(this._compute);

  getValue(List positionalArguments, [Map<Symbol, dynamic> namedArguments =
      const {}]) => values.putIfAbsent(new MethodArguments(positionalArguments,
      namedArguments), () => Function.apply(_compute, positionalArguments,
      namedArguments));
}
/// An implementation of [Cache] that computes the result only once and always returns the same result.
class CustomCache implements Cache {
  final Function _compute;
  final Map<MethodArguments, dynamic> values;
  final int maxCapacity;
  final Duration expireAfterAccess;
  final Duration expireAfterWrite;

  final _expireAfterAccessTimers = new HashMap<MethodArguments, Timer>();
  final _expireAfterWriteTimers = new HashMap<MethodArguments, Timer>();

  CustomCache(this._compute, {int
      maxCapacity, this.expireAfterAccess, this.expireAfterWrite})
      : maxCapacity = maxCapacity,
        values = (maxCapacity == null ? new HashMap<MethodArguments, dynamic>() :
          new LinkedHashMap<MethodArguments, dynamic>());

  getValue(List positionalArguments, [Map<Symbol, dynamic> namedArguments =
      const {}]) {
    final cacheKey = new MethodArguments(positionalArguments, namedArguments);

    // expiration on access handling
    if (expireAfterAccess != null) {
      _removeTimer(cacheKey, _expireAfterAccessTimers);
      _expireAfterAccessTimers[cacheKey] = new Timer(expireAfterAccess, () {
        _removeTimer(cacheKey, _expireAfterAccessTimers);
        values.remove(cacheKey);
      });
    }

    // maxCapacity exceeded: remove the last accessed key (at first position)
    if (maxCapacity != null && values.length >= maxCapacity &&
        values.isNotEmpty) {
      values.remove(values.keys.first);
    }

    // get or compute
    bool isNew = false;
    final result = values.putIfAbsent(cacheKey, () {
      isNew = true;

      // expiration on write handling
      if (expireAfterWrite != null) {
        _removeTimer(cacheKey, _expireAfterWriteTimers);
        _expireAfterWriteTimers[cacheKey] = new Timer(expireAfterWrite, () {
          _removeTimer(cacheKey, _expireAfterWriteTimers);
          values.remove(cacheKey);
        });
      }

      return Function.apply(_compute, positionalArguments, namedArguments);
    });

    // maxCapacity: put the Last Read at the lastest position
    if (maxCapacity != null && !isNew) {
      values[cacheKey] = values.remove(cacheKey);
    }

    return result;
  }

  void _removeTimer(MethodArguments cacheKey, Map<MethodArguments, Timer> timers) {
    final t = timers.remove(cacheKey);
    if (t != null) t.cancel();
  }
}
