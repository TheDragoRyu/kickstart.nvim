; Extends the bundled c_sharp folds.scm so that whole declarations fold
; (signature + body), not just the body block. Also adds #region support.

[
  (method_declaration)
  (constructor_declaration)
  (destructor_declaration)
  (operator_declaration)
  (conversion_operator_declaration)
  (local_function_statement)
  (property_declaration)
  (indexer_declaration)
  (event_declaration)
  (class_declaration)
  (struct_declaration)
  (interface_declaration)
  (record_declaration)
  (enum_declaration)
  (namespace_declaration)
  (file_scoped_namespace_declaration)
] @fold

(preproc_region) @fold
