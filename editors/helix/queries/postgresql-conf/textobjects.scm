(setting) @entry.around

(setting
  value: (_) @entry.inside)

(hba_rule) @entry.around

(user_mapping) @entry.around

(auth_option) @parameter.around

(auth_option
  value: (_) @parameter.inside)

(comment)+ @comment.around
