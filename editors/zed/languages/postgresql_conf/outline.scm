(setting
  name: (setting_name) @name) @item

(hba_rule
  type: (connection_type) @context
  database: (database) @name
  user: (user) @context.extra) @item

(user_mapping
  map: (map_name) @name
  system_user: (_) @context) @item
