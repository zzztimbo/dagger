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

	// App name (for cache scoping)
	app: string

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

// Compile Elixir dependencies, including the app
#Compile: {
	// Ref to base image
	// FIXME: spin out docker.#Build for max flexibility
	// Perhaps implement as a custom docker.#Build step?
	base: docker.#Ref

	// App name (for cache scoping)
	app: string

	// Mix environment
	app_env: string

	// Application source code
	source: dagger.#FS

	#Run & {
		mix: {
			"app":      app
			"env":      app_env
			depsCache:  "private"
			buildCache: "locked"
		}
		workdir: "/app"
		script:  "mix do deps.compile, compile"
	}
}

// Run mix task with all necessary mounts so compiled artefacts get cached
#Run: {
	mix: {
		app: string
		env: string | *""
		// FIXME: "ro" | "rw"
		depsCache?:  "private" | "locked" | "shared"
		buildCache?: "private" | "locked" | "shared"
	}
	docker.#Run
	env: MIX_ENV: mix.env
	workdir: string
	if mix.depsCache != _|_ {
		mounts: depsCache: {
			contents: engine.#CacheDir & {
				id:          "\(mix.app)_deps"
				concurrency: mix.depsCache
			}
			dest: "\(workdir)/deps"
		}
	}
	if mix.buildCache != _|_ {
		mounts: buildCache: {
			contents: engine.#CacheDir & {
				id:          "\(mix.app)_deps"
				concurrency: mix.buildCache
			}
			dest: "\(workdir)/deps"
		}
	}
}
