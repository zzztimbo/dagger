package mix

import (
	"dagger.io/dagger"
	"dagger.io/dagger/engine"

	"universe.dagger.io/docker"
)

// Get Elixir dependencies
#Get: {
	// Application source code
	source: dagger.#FS

	#Run & {
		mix: {
			depsCache: "locked"
			env:       null
		}
		mounts: "app": {
			contents: source
			dest:     "/app"
		}
		script:  "mix deps.get"
		workdir: "/app"
	}
}

// Compile Elixir dependencies, including the app
#Compile: {
	// Application source code
	source: dagger.#FS

	#Run & {
		mix: {
			buildCache: "locked"
			depsCache:  "locked"
			env:        string
		}
		mounts: "app": {
			contents: source
			dest:     "/app"
		}
		script:  "mix do deps.compile, compile"
		workdir: "/app"
	}
}

// Run mix task with all necessary mounts so compiled artefacts get cached
// FIXME: add default image to hexpm/elixir:1.13.2-erlang-23.3.4.11-debian-bullseye-20210902
#Run: {
	mix: {
		app: string
		env: string | null
		// FIXME: "ro" | "rw"
		depsCache:  *null | "locked"
		buildCache: *null | "locked"
	}
	docker.#Run
	if mix.env != null {
		env: MIX_ENV: mix.env
	}
	workdir: string
	if mix.depsCache != null {
		mounts: depsCache: {
			contents: engine.#CacheDir & {
				id:          "\(mix.app)_deps"
				concurrency: mix.depsCache
			}
			dest: "\(workdir)/deps"
		}
	}
	if mix.buildCache != null {
		mounts: buildCache: {
			contents: engine.#CacheDir & {
				id:          "\(mix.app)_build_\(mix.env)"
				concurrency: mix.buildCache
			}
			dest: "\(workdir)/_build/\(mix.env)"
		}
	}
}
