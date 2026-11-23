[
  import_deps: [:phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  export: [locals_without_parens: [ha_auth_routes: 0, ha_auth_routes: 1]]
]
