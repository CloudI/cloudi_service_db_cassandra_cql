defmodule CloudIServiceDbCassandraCql do
  use Mix.Project

  def project do
    [app: :cloudi_service_db_cassandra_cql,
     version: "1.5.0",
     language: :erlang,
     description: description,
     package: package,
     deps: deps]
  end

  defp deps do
    [{:erlcql,
      [git: "https://github.com/rpt/erlcql.git",
       branch: "develop"]},
     {:cloudi_core, "~> 1.5.0"}]
  end

  defp description do
    "Erlang/Elixir Cloud Framework Cassandra CQL Service"
  end

  defp package do
    [files: ~w(src doc test rebar.config README.markdown),
     contributors: ["Irina Guberman", "Michael Truog"],
     licenses: ["BSD"],
     links: %{"Website" => "http://cloudi.org",
              "GitHub" => "https://github.com/CloudI/" <>
                          "cloudi_service_db_cassandra_cql"}]
   end
end
