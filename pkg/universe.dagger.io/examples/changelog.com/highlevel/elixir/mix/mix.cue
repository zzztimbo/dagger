package mix

import (
	"dagger.io/dagger"
	"dagger.io/dagger/engine"

	"universe.dagger.io/docker"
)

// Get Elixir dependencies
#Get: {
	// Ref to base image
	// FIXME: spin out docker.#Build for max flexibility
	// Perhaps implement as a custom docker.#Build step?
	base: docker.#Ref

	mix: {
		app: string
	}

	// Application source code
	source: dagger.#FS

	docker.#Build & {
		// DISCUSS:
		// If the output of the previous step is used as the input of the next step,
		// then "steps" is the wrong name for this.
		// "pipeline" sounds better - I am thinking about the UNIX & Elixir "pipe"
		steps: [
			// 1. Pull base image
			docker.#Pull & {
				source: base
			},
			// 2. Copy app source
			docker.#Copy & {
				contents: source
				dest:     "/app"
			},
			// 3. Download dependencies into deps cache
			#Run & {
				mix: {
					"app":     app
					depsCache: "shared"
				}
				workdir: "/app"
				script:  "mix deps.get"
			},
		]
	}
}

#Get: {
	// Application source code
	source: dagger.#FS

	#Run & {
		mix: {
			buildCache: "locked"
			depsCache:  "private"
		}
		mounts: "app": {
			contents: source
			dest:     "/app"
		}
		script:  "mix do deps.compile, compile"
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
			depsCache:  "private"
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
		env: string | *""
		// FIXME: "ro" | "rw"
		depsCache:  *null | "private" | "locked" | "shared"
		buildCache: *null | "private" | "locked" | "shared"
	}
	docker.#Run
	env: MIX_ENV: mix.env
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
