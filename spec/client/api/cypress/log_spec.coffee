describe "$Cypress.Log API", ->

  describe "instances", ->
    beforeEach ->
      @Cypress = $Cypress.create()
      @log = new $Cypress.Log @Cypress

    it "sets state to pending by default", ->
      expect(@log.attributes).to.deep.eq {state: "pending"}

    it "#get", ->
      @log.set "bar", "baz"
      expect(@log.get("bar")).to.eq "baz"

    it "#pick", ->
      @log.set "one", "one"
      @log.set "two", "two"

      expect(@log.pick("one", "two")).to.deep.eq {
        one: "one"
        two: "two"
      }

    it "#snapshot", ->
      createSnapshot = @sandbox.stub @Cypress, "createSnapshot"

      div = $("<div />")
      @log.set "$el", div

      @log.snapshot()

      expect(createSnapshot).to.be.calledWith div

    it "#error", ->
      err = new Error
      @log.error(err)
      expect(@log.get("state")).to.eq "failed"
      expect(@log.get("error")).to.eq err

    it "#error triggers attrs:changed", (done) ->
      @log.on "attrs:changed", (attrs) ->
        expect(attrs.state).to.eq "failed"
        done()

      @log.error({})

    it "#end", ->
      @log.end()
      expect(@log.get("state")).to.eq "passed"

    it "#end triggers attrs:changed", (done) ->
      @log.on "attrs:changed", (attrs) ->
        expect(attrs.state).to.eq "passed"
        done()

      @log.end()

    describe "#set", ->
      it "string", ->
        @log.set "foo", "bar"
        expect(@log.attributes.foo).to.eq "bar"

      it "object", ->
        @log.set {foo: "bar", baz: "quux"}
        expect(@log.attributes).to.deep.eq {foo: "bar", baz: "quux", state: "pending"}

      it "triggers attrs:changed with attribues", (done) ->
        @log.on "attrs:changed", (attrs) =>
          expect(attrs.foo).to.eq "bar"
          expect(attrs.baz).to.eq "quux"
          expect(attrs).to.deep.eq @log.attributes
          done()

        @log.set {foo: "bar", baz: "quux"}

    describe "#setElAttrs", ->
      beforeEach ->
        @$el = $("<div />").appendTo($("body"))

      afterEach ->
        @$el.remove()

      it "is called if $el is passed during construction", ->
        setElAttrs = @sandbox.stub $Cypress.Log.prototype, "setElAttrs"

        new $Cypress.Log @Cypress, $el: {}

        expect(setElAttrs).to.be.called

      it "is called if $el is passed during #set", ->
        setElAttrs = @sandbox.stub $Cypress.Log.prototype, "setElAttrs"

        log = new $Cypress.Log @Cypress
        log.set $el: {}

        expect(setElAttrs).to.be.called

      it "sets $el", ->
        log = new $Cypress.Log @Cypress, $el: @$el
        expect(log.get("$el")).to.eq @$el

      it "sets highlightAttr", ->
        @log.set($el: @$el)
        expect(@log.get("highlightAttr")).to.be.ok
        expect(@log.get("highlightAttr")).to.eq @Cypress.highlightAttr

      it "sets numElements", ->
        @log.set($el: @$el)
        expect(@log.get("numElements")).to.eq @$el.length

      it "sets visible to true", ->
        @$el.css({height: 100, width: 100})
        @log.set($el: @$el)
        expect(@log.get("visible")).to.be.true

      it "sets visible to false", ->
        @$el.hide()
        @log.set($el: @$el)
        expect(@log.get("visible")).to.be.false

      it "sets visible to false if any $el is not visible", ->
        $btn1 = $("<button>one</button>").appendTo($("body"))
        $btn2 = $("<button>two</button>").appendTo($("body")).hide()

        $el = $btn1.add($btn2)
        expect($el.length).to.eq 2

        @log.set($el: $el)

        expect(@log.get("visible")).to.be.false
        $el.remove()

    describe "#constructor", ->
      it "snapshots if snapshot attr is true", ->
        createSnapshot = @sandbox.stub @Cypress, "createSnapshot"

        new $Cypress.Log @Cypress, snapshot: true

        expect(createSnapshot).to.be.called

      it "ends if end attr is true", ->
        end = @sandbox.stub $Cypress.Log.prototype, "end"

        new $Cypress.Log @Cypress, end: true

        expect(end).to.be.called

      it "errors if error attr is defined", ->
        error = @sandbox.stub $Cypress.Log.prototype, "error"

        err = new Error

        new $Cypress.Log @Cypress, error: err

        expect(error).to.be.calledWith err

    describe "#wrapOnConsole", ->
      it "automatically adds Command with name", ->
        @log.set("name", "foo")
        @log.set("snapshots", [{name: null, state: {}}])
        @log.set("onConsole", -> {bar: "baz"})
        @log.wrapOnConsole()
        expect(@log.attributes.onConsole()).to.deep.eq {
          Command: "foo"
          bar: "baz"
        }

      it "automatically adds Event with name", ->
        @log.set({name: "foo", event: true, snapshot: {}})
        @log.set("onConsole", -> {bar: "baz"})
        @log.wrapOnConsole()
        expect(@log.attributes.onConsole()).to.deep.eq {
          Event: "foo"
          bar: "baz"
        }

      it "adds a note when snapshot is missing", ->
        @log.set("name", "foo")
        @log.set("instrument", "command")
        @log.set("onConsole", -> {})
        @log.wrapOnConsole()
        expect(@log.attributes.onConsole().Snapshot).to.eq "The snapshot is missing. Displaying current state of the DOM."

    describe "#publicInterface", ->
      beforeEach ->
        @interface = @log.publicInterface()

      it "#get", ->
        @log.set "foo", "bar"
        expect(@interface.get("foo")).to.eq "bar"

      it "#pick", ->
        @log.set "bar", "baz"
        expect(@interface.pick("bar")).to.deep.eq {bar: "baz"}

      it "#on", (done) ->
        m = new Backbone.Model
        m.listenTo @interface, "foo", done
        @log.trigger "foo"

      it "#off", ->
        @log.on "foo", ->
        expect(@log._events).not.to.be.empty
        @interface.off "foo"
        expect(@log._events).to.be.empty

    describe "#snapshot", ->
      beforeEach ->
        @sandbox.stub(@Cypress, "createSnapshot").returns({})

      it "can set multiple snapshots", ->
        @log.snapshot()
        @log.snapshot()

        expect(@log.get("snapshots").length).to.eq(2)

      it "can name the snapshot", ->
        @log.snapshot("logging in")
        expect(@log.get("snapshots").length).to.eq(1)
        expect(@log.get("snapshots")[0].name).to.eq("logging in")

      it "can set multiple named snapshots", ->
        @log.snapshot("one")
        @log.snapshot("two")

        snapshots = @log.get("snapshots")
        expect(snapshots[0].name).to.eq("one")
        expect(snapshots[1].name).to.eq("two")

      it "can insert snapshot at specific position", ->
        @log.snapshot("one")
        @log.snapshot("two")
        @log.snapshot("three")
        @log.snapshot("replacement", {at: 1})

        snapshots = @log.get("snapshots")
        expect(snapshots.length).to.eq(3)
        expect(snapshots[0].name).to.eq("one")
        expect(snapshots[1].name).to.eq("replacement")
        expect(snapshots[2].name).to.eq("three")

      it "can automatically set the name of the next snapshot", ->
        @log.snapshot("before", {next: "after"})
        @log.snapshot("asdfasdf") ## should ignore this name
        @log.snapshot("third")

        snapshots = @log.get("snapshots")
        expect(snapshots.length).to.eq(3)
        expect(snapshots[0].name).to.eq("before")
        expect(snapshots[1].name).to.eq("after")
        expect(snapshots[2].name).to.eq("third")

  describe "class methods", ->
    enterCommandTestingMode()

    context ".create", ->
      beforeEach ->
        @Cypress.Log.create(@Cypress, @cy)

        obj = {name: "foo", ctx: @cy, fn: (->), args: [1,2,3], type: "parent"}
        @cy.prop("current", @Cypress.Command.create(obj))

      describe "#command", ->
        it "displays a deprecation warning", ->
          warn = @sandbox.spy console, "warn"
          @Cypress.command({})
          expect(warn).to.be.calledWith "Cypress Warning: Cypress.command() is deprecated. Please update and use: Cypress.Log.command()"

      context "$Log.log", ->
        it "displays 0 argument", (done) ->
          @Cypress.on "log", (obj) ->
            if obj.get("name") is "eq"
              expect(obj.get("message")).to.eq "0"
              done()

          @cy.get("div").eq(0)

        it "sets type to 'parent' dual commands when first command", (done) ->
          @allowErrors()

          @Cypress.on "log", (obj) ->
            if obj.get("name") is "then"
              expect(obj.get("type")).to.eq "parent"
              done()

          @cy.then ->
            throw new Error("then failure")

        it "sets type to 'child' dual commands when first command", (done) ->
          @allowErrors()

          @Cypress.on "log", (obj) ->
            if obj.get("name") is "then"
              expect(obj.get("type")).to.eq "child"
              done()

          @cy.noop({}).then ->
            throw new Error("then failure")

        describe "defaults", ->
          it "sets name to current.name", (done) ->
            @Cypress.on "log", (obj) ->
              expect(obj.get("name")).to.eq "foo"
              done()

            @Cypress.Log.command({})

          it "sets type to current.type", (done) ->
            @Cypress.on "log", (obj) ->
              expect(obj.get("type")).to.eq "parent"
              done()

            @Cypress.Log.command({})

          it "sets message to stringified args", (done) ->
            @Cypress.on "log", (obj) ->
              expect(obj.get("message")).to.deep.eq "1, 2, 3"
              done()

            @Cypress.Log.command({})

          it "omits ctx from current.ctx", (done) ->
            @Cypress.on "log", (obj) ->
              expect(obj.get("ctx")).not.to.exist
              done()

            @Cypress.Log.command({})

          it "omits fn from current.fn", (done) ->
            @Cypress.on "log", (obj) ->
              expect(obj.get("fn")).not.to.exist
              done()

            @Cypress.Log.command({})

          it "sets hookName to prop hookName", (done) ->
            @cy.private("hookName", "beforeEach")

            @Cypress.on "log", (obj) ->
              expect(obj.get("hookName")).to.eq "beforeEach"
              @private("hookName", null)
              done()

            @Cypress.Log.command({})

          it "sets viewportWidth to private viewportWidth", (done) ->
            @Cypress.config("viewportWidth", 999)

            @Cypress.on "log", (obj) ->
              expect(obj.get("viewportWidth")).to.eq 999
              done()

            @Cypress.Log.command({})

          it "sets viewportHeight to private viewportHeight", (done) ->
            @Cypress.config("viewportHeight", 888)

            @Cypress.on "log", (obj) ->
              expect(obj.get("viewportHeight")).to.eq 888
              done()

            @Cypress.Log.command({})

          it "sets url to private url", (done) ->
            @cy.private("url", "www.github.com")

            @Cypress.on "log", (obj) ->
              expect(obj.get("url")).to.eq "www.github.com"
              done()

            @Cypress.Log.command({})

          it "sets testId to runnable.id", (done) ->
            @cy.private("runnable", {id: 123})

            @Cypress.on "log", (obj) ->
              expect(obj.get("testId")).to.eq 123
              @private("runnable", null)
              done()

            @Cypress.Log.command({})

          it "sets numElements if $el", (done) ->
            $el = @cy.$$("body")

            @Cypress.on "log", (obj) ->
              expect(obj.get("numElements")).to.eq 1
              done()

            @Cypress.Log.command($el: $el)

          it "sets highlightAttr if $el", (done) ->
            $el = @cy.$$("body")

            @Cypress.on "log", (obj) ->
              expect(obj.get("highlightAttr")).not.to.be.undefined
              expect(obj.get("highlightAttr")).to.eq @Cypress.highlightAttr
              done()

            @Cypress.Log.command($el: $el)

        describe "errors", ->
          beforeEach ->
            @allowErrors()

            @cy.on "command:start", ->
              @_timeout(100)

            ## prevent accidentally adding a .then to @cy
            return null

          it "preserves errors", (done) ->
            @Cypress.on "log", (@log) =>

            @cy.on "fail", (err) =>
              expect(@log.get("name")).to.eq "get"
              expect(@log.get("message")).to.eq "foo"
              expect(@log.get("error")).to.eq err
              done()

            @cy.get("foo")

          it "#onConsole for parent commands", (done) ->
            @Cypress.on "log", (@log) =>

            @cy.on "fail", (err) =>
              expect(@log.attributes.onConsole()).to.deep.eq {
                Command: "get"
                Selector: "foo"
                Elements: 0
                Returned: undefined
                Error: err.toString()
              }
              done()

            @cy.get("foo")

          it "#onConsole for dual commands as a parent", (done) ->
            @Cypress.on "log", (@log) =>

            @cy.on "fail", (err) =>
              expect(@log.attributes.onConsole()).to.deep.eq {
                Command: "wait"
                Error: err.toString()
              }
              done()

            @cy.wait ->
              expect(true).to.be.false

          it "#onConsole for dual commands as a child", (done) ->
            @Cypress.on "log", (@log) =>

            @cy.on "fail", (err) =>
              if @log.get("name") is "wait"
                btns = getFirstSubjectByName.call(@, "get")
                expect(@log.attributes.onConsole()).to.deep.eq {
                  Command: "wait"
                  "Applied To": $Cypress.Utils.getDomElements(btns)
                  Error: err.toString()
                }
                done()

            @cy.get("button").wait ->
              expect(true).to.be.false

          it "#onConsole for children commands", (done) ->
            @Cypress.on "log", (@log) =>

            @cy.on "fail", (err) =>
              if @log.get("name") is "contains"
                btns = getFirstSubjectByName.call(@, "get")
                expect(@log.attributes.onConsole()).to.deep.eq {
                  Command: "contains"
                  Content: "asdfasdfasdfasdf"
                  Elements: 0
                  Returned: undefined
                  "Applied To": $Cypress.Utils.getDomElements(btns)
                  Error: err.toString()
                }
                done()

            @cy.get("button").contains("asdfasdfasdfasdf")

          it "#onConsole for nested children commands", (done) ->
            @Cypress.on "log", (@log) =>

            @cy.on "fail", (err) =>
              if @log.get("name") is "contains"
                expect(@log.attributes.onConsole()).to.deep.eq {
                  Command: "contains"
                  Content: "asdfasdfasdfasdf"
                  Elements: 0
                  Returned: undefined
                  "Applied To": getFirstSubjectByName.call(@, "eq").get(0)
                  Error: err.toString()
                }
                done()

            @cy.get("button").eq(0).contains("asdfasdfasdfasdf")