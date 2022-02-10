package changelog

import (
	"dagger.io/dagger"

	"universe.dagger.io/docker"
	"universe.dagger.io/git"
	"universe.dagger.io/examples/changelog.com/elixir/mix"
)

dagger.#Plan & {
	// Receive things from client
	inputs: {
		directories: {
			app?: {
				// Path to app source code
				path: string
				include: [
					"assets",
					"config",
					"docker",
					"lib",
					"priv/grafana_dashboards",
					"priv/honeycomb_dashboards",
					"priv/repo",
					"priv/static",
					"test",
					".*.exs",
					"Makefile",
					"coveralls.json",
					"mix.*",
				]
			}
		}
		secrets: {
			// Docker ID password
			docker: _
		}
		params: {
			app: {
				// App name
				name: string | *"changelog"

				// Address of app base image
				image: docker.#Ref | *"thechangelog/runtime:2021-05-29T10.17.12Z"
			}

			test: {
				// Address of test db image
				db: image: docker.#Ref | *"circleci/postgres:12.6"
			}
		}
	}

	// Do things
	actions: {
		app: {
			name: inputs.params.app.name

			// changelog.com source code
			source: dagger.#FS
			if inputs.directories.app != _|_ {
				source: inputs.directories.app.contents
			}
			if inputs.directories.app == _|_ {
				fetch: git.#Pull & {
					remote: "https://github.com/thechangelog/changelog.com"
					ref:    "master"
				}
				source: fetch.output
			}

			// Assemble base image
			base: docker.#Pull & {
				source: inputs.params.app.image
			}
			image: base.output

			// Download Elixir dependencies
			deps_get: mix.#Get & {
				app: {
					"name":   name
					"source": source
				}
				container: input: image
			}

			test_env_compile: mix.#Compile & {
				env: "test"
				app: {
					"name":   name
					"source": source
				}
				container: input: deps_get.container.output
			}

			prod_env_compile: mix.#Compile & {
				env: "prod"
				app: {
					"name":   name
					"source": source
				}
				container: input: deps_get.container.output
			}

			// vvv CONTINUE vvv
			static_assets_compile: {
				container: input: image
			}

			static_assets_digest: {
				container: input: static_assets_compile.container.output
			}

			// Copies mounts from:
			// - deps_get
			// - prod_env_compile
			// - static_assets_digest
			//
			// 🤔 How to depend on multiple actions?
			// 1. prod_env_compile
			// 2. static_assets_digest
			prod_image_build: {}

			// Start PostgreSQL container
			test_db_start: {}

			// Run tests against PostgreSQL container
			test: {
				container: input: test_env_compile.container.output
			}

			test_db_stop: {
				container: input: test.container.output
			}

			// 🤔 How to depend on multiple actions?
			// 1. prod_image_build
			// 2. test
			// Be optimistic and tag container image locally
			prod_image_publish: {}
		}
	}
}
