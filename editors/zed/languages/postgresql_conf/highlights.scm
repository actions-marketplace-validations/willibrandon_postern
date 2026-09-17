; postgresql.conf

(setting
  name: (setting_name) @property)

(string) @string

(number) @number

(unit) @type

(boolean) @boolean

(bare_value) @constant

"=" @operator

; include, include_if_exists and include_dir

(include
  [
    "include"
    "include_if_exists"
    "include_dir"
  ] @keyword)

(include
  path: (path) @string.special)

(include
  path: (string) @string.special)

; pg_hba.conf

(connection_type) @keyword

(name) @variable

((name) @constant
  (#any-of? @constant "all" "sameuser" "samerole" "samegroup" "replication"))

(role_group
  "+" @punctuation.special)

(file_reference
  "@" @punctuation.special
  (path) @string.special)

(regex) @string.regex

(quoted_name) @string

(ip_address) @string.special

(hostname) @string.special

((hostname) @constant
  (#any-of? @constant "all" "samehost" "samenet"))

(netmask) @string.special

(auth_method) @function

(auth_option
  name: (option_name) @variable.special)

(auth_option
  value: (option_value) @string)

"," @punctuation.delimiter

; pg_ident.conf

(user_mapping
  map: (map_name) @type)

(system_user) @string

(database_user) @variable

(backreference) @string.special

(comment) @comment
