// GENERATED CODE - DO NOT MODIFY BY HAND

part of zengen.example.delegate;

// **************************************************************************
// Generator: ZengenGenerator
// Target: library zengen.example.delegate
// **************************************************************************

@GeneratedFrom(_B)
class B implements A<int> {
  A<int> _a;
  int m1() => _a.m1();
}

@GeneratedFrom(_C)
class C implements List<String> {
  List<String> _l;
  String elementAt(int index) => _l.elementAt(index);
  String singleWhere(bool test(String element)) => _l.singleWhere(test);
  String lastWhere(bool test(String element), {String orElse()}) =>
      _l.lastWhere(test, orElse: orElse);
  String firstWhere(bool test(String element), {String orElse()}) =>
      _l.firstWhere(test, orElse: orElse);
  Iterable<String> skipWhile(bool test(String value)) => _l.skipWhile(test);
  Iterable<String> skip(int count) => _l.skip(count);
  Iterable<String> takeWhile(bool test(String value)) => _l.takeWhile(test);
  Iterable<String> take(int count) => _l.take(count);
  Set<String> toSet() => _l.toSet();
  List<String> toList({bool growable: true}) => _l.toList(growable: growable);
  bool any(bool f(String element)) => _l.any(f);
  String join([String separator = ""]) => _l.join(separator);
  bool every(bool f(String element)) => _l.every(f);
  dynamic fold(dynamic initialValue,
          dynamic combine(dynamic previousValue, String element)) =>
      _l.fold(initialValue, combine);
  String reduce(String combine(String value, String element)) =>
      _l.reduce(combine);
  void forEach(void f(String element)) {
    _l.forEach(f);
  }

  bool contains(Object element) => _l.contains(element);
  Iterable expand(Iterable f(String element)) => _l.expand(f);
  Iterable<String> where(bool f(String element)) => _l.where(f);
  Iterable map(dynamic f(String element)) => _l.map(f);
  String get single => _l.single;
  String get last => _l.last;
  String get first => _l.first;
  bool get isNotEmpty => _l.isNotEmpty;
  bool get isEmpty => _l.isEmpty;
  Iterator<String> get iterator => _l.iterator;
  Map<int, String> asMap() => _l.asMap();
  void replaceRange(int start, int end, Iterable<String> replacement) {
    _l.replaceRange(start, end, replacement);
  }

  void fillRange(int start, int end, [String fillValue]) {
    _l.fillRange(start, end, fillValue);
  }

  void removeRange(int start, int end) {
    _l.removeRange(start, end);
  }

  void setRange(int start, int end, Iterable<String> iterable,
      [int skipCount = 0]) {
    _l.setRange(start, end, iterable, skipCount);
  }

  Iterable<String> getRange(int start, int end) => _l.getRange(start, end);
  List<String> sublist(int start, [int end]) => _l.sublist(start, end);
  void retainWhere(bool test(String element)) {
    _l.retainWhere(test);
  }

  void removeWhere(bool test(String element)) {
    _l.removeWhere(test);
  }

  String removeLast() => _l.removeLast();
  String removeAt(int index) => _l.removeAt(index);
  bool remove(Object value) => _l.remove(value);
  void setAll(int index, Iterable<String> iterable) {
    _l.setAll(index, iterable);
  }

  void insertAll(int index, Iterable<String> iterable) {
    _l.insertAll(index, iterable);
  }

  void insert(int index, String element) {
    _l.insert(index, element);
  }

  void clear() {
    _l.clear();
  }

  int lastIndexOf(String element, [int start]) =>
      _l.lastIndexOf(element, start);
  int indexOf(String element, [int start = 0]) => _l.indexOf(element, start);
  void shuffle([Random random]) {
    _l.shuffle(random);
  }

  void sort([int compare(String a, String b)]) {
    _l.sort(compare);
  }

  void addAll(Iterable<String> iterable) {
    _l.addAll(iterable);
  }

  void add(String value) {
    _l.add(value);
  }

  void operator []=(int index, String value) {
    _l[index] = value;
  }

  String operator [](int index) => _l[index];
  Iterable<String> get reversed => _l.reversed;
  set length(int newLength) {
    _l.length = newLength;
  }

  int get length => _l.length;
}
