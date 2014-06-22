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

import 'to_string_test.dart' as to_string;
import 'equals_and_hashcode_test.dart' as equals_and_hashcode;
import 'library_with_parts_test.dart' as library_with_parts;
import 'delegate_test.dart' as delegate;
import 'lazy_test.dart' as lazy;
import 'default_constructor_test.dart' as default_constructor;
import 'value_test.dart' as value;
import 'implementation_test.dart' as implementation;
import 'cached_test.dart' as cached;

main() {
  to_string.main();
  equals_and_hashcode.main();
  library_with_parts.main();
  delegate.main();
  lazy.main();
  default_constructor.main();
  value.main();
  implementation.main();
  cached.main();
}
