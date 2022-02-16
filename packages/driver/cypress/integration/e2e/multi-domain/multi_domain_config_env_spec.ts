['config', 'env'].forEach((fnName) => {
  // @ts-ignore
  describe(`multi-domain - Cypress.Cypress.${fnName}()`, { experimentalSessionSupport: true, experimentalMultiDomain: true }, () => {
    beforeEach(() => {
      cy.visit('/fixtures/multi-domain.html')
      cy.get('a[data-cy="multi-domain-secondary-link"]').click()
    })

    afterEach(() => {
      // @ts-ignore
      window.top.__cySkipValidateConfig = true
    })

    if (fnName === 'config') {
      it(`throws if mutating read-only config values with Cypress.config()`, (done) => {
        // @ts-ignore
        window.top.__cySkipValidateConfig = false
        cy.on('fail', (err) => {
          expect(err.message).to.include('`Cypress.config()` cannot mutate option `chromeWebSecurity` because it is a read-only property.')
          done()
        })

        cy.switchToDomain('foobar.com', () => {
          // @ts-ignore
          Cypress.config('chromeWebSecurity', false)
        })
      })
    }

    context('serializable', () => {
      it(`syncs initial Cypress.${fnName}() from the primary domain to the secondary (synchronously)`, () => {
        Cypress[fnName]('foo', 'bar')
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const isBar = Cypress[fnName]('foo')

          expect(isBar).to.equal('bar')
        })
      })

      it(`syncs serializable values in the Cypress.${fnName}() again to the secondary even after spec bridge is created`, () => {
        Cypress[fnName]('foo', 'baz')
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const baz = Cypress[fnName]('foo')

          expect(baz).to.equal('baz')
        })
      })

      it(`syncs serializable Cypress.${fnName}() values outwards from secondary (synchronously)`,
        () => {
          cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
            Cypress[fnName]('bar', 'baz')
          })

          Cypress[fnName]('bar', 'foo')

          cy.wrap({}).then(() => {
            const baz = Cypress[fnName]('bar')

            expect(baz).to.equal('baz')
          })
        })

      // FIXME: unskip this test once tail-end waiting is implemented
      it.skip(`syncs serializable Cypress.${fnName}() values outwards from secondary (commands/async)`, () => {
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          cy.wrap({}).then(() => {
            Cypress[fnName]('bar', 'quux')
          })
        })

        cy.wrap({}).then(() => {
          const quux = Cypress[fnName]('bar')

          expect(quux).to.equal('quux')
        })
      })

      it(`persists Cypress.${fnName}() changes made in the secondary, assuming primary has not overwritten with a serializable value`, {}, () => {
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const baz = Cypress[fnName]('bar')

          expect(baz).to.equal('baz')
        })
      })

      it(`does NOT sync Cypress.${fnName}() changes made in the secondary after the command queue is finished and the callback window is closed`, {
        // @ts-ignore
        baz: undefined,
        env: {
          baz: undefined,
        },
      }, (done) => {
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          setTimeout(() => {
            // this value STILL gets set, but will be blown away on the next switchToDomain with whatever exists in the primary
            Cypress[fnName]('baz', 'qux')
          }, 100)

          Cypress[fnName]('baz', 'quux')
        })

        const isUndefined = Cypress[fnName]('baz')

        expect(isUndefined).to.be.undefined

        cy.wrap({}).then(() => {
          const isQuux = Cypress[fnName]('baz')

          expect(isQuux).to.equal('quux')
          done()
        })
      })

      it('overwrites different values in secondary if one exists in the primary', {
        // @ts-ignore
        baz: 'quux',
        env: {
          baz: 'quux',
        },
      }, () => {
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          // in previous test, 'baz' was set to 'qux' after the callback window was closed.
          // this should be overwritten by 'quux' that exists in the primary
          const isNowQuux = Cypress[fnName]('baz')

          expect(isNowQuux).to.equal('quux')
        })
      })

      it(`overwrites different values in secondary, even if the Cypress.${fnName}() value does not exist in the primary`, {
        // @ts-ignore
        baz: undefined,
        env: {
          baz: undefined,
        },
      }, () => {
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const isNowUndefined = Cypress[fnName]('baz')

          expect(isNowUndefined).to.be.undefined
        })
      })
    })

    context('unserializable', () => {
      const unserializableFunc = () => undefined

      it('does not sync unserializable values from the primary to the secondary', () => {
        Cypress[fnName]('unserializable', unserializableFunc)
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const isUndefined = Cypress[fnName]('unserializable')

          expect(isUndefined).to.be.undefined
        })
      })

      it('does not overwrite unserializable values in the primary when none exist in the secondary', () => {
        Cypress[fnName]('unserializable', unserializableFunc)
        cy.switchToDomain('foobar.com', () => undefined)

        const isFunc = Cypress[fnName]('unserializable')

        expect(isFunc).to.equal(unserializableFunc)
      })

      it('overwrites unserializable values in the primary when serializable values of same key exist in secondary', () => {
        Cypress[fnName]('unserializable', unserializableFunc)
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          Cypress[fnName]('unserializable', undefined)
        })

        cy.wrap({}).then(() => {
          const isNowUndefined = Cypress[fnName]('undefined')

          expect(isNowUndefined).to.be.undefined
        })
      })

      it('overwrites unserializable values in the secondary when serializable values of same key exist in primary', () => {
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const unserializableFuncSecondary = () => undefined

          Cypress[fnName]('unserializable', unserializableFuncSecondary)
        })

        cy.wrap({}).then(() => {
          Cypress[fnName]('unserializable', undefined)
        })

        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const isUndefined = Cypress[fnName]('unserializable')

          expect(isUndefined).to.be.undefined
        })

        cy.wrap({}).then(() => {
          const isUndefined = Cypress[fnName]('unserializable')

          expect(isUndefined).to.be.undefined
        })
      })

      it('does not overwrite unserializable values in the primary when unserializable values of same key exist in secondary', () => {
        Cypress[fnName]('unserializable', unserializableFunc)
        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const unserializableFuncSecondary = () => undefined

          Cypress[fnName]('unserializable', unserializableFuncSecondary)
        })

        cy.wrap({}).then(() => {
          const isFunc = Cypress[fnName]('unserializable')

          expect(isFunc).to.equal(unserializableFunc)
        })
      })

      it('does not try to merge objects that contain unserializable values', () => {
        const partiallyUnserializableObject = {
          a: 1,
          b: document.createElement('h1'),
        }

        Cypress[fnName]('unserializable', partiallyUnserializableObject)

        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const doesNotContainPartialAProperty = Cypress[fnName]('unserializable')

          expect(doesNotContainPartialAProperty?.a).to.be.undefined

          Cypress[fnName]('unserializable', {
            a: 3,
            c: document.createElement('h1'),
          })
        })

        cy.wrap({}).then(() => {
          const isPartiallyUnserializableObject = Cypress[fnName]('unserializable')

          expect(isPartiallyUnserializableObject.a).to.equal(1)
        })
      })
    })

    context('structuredClone()', () => {
      it('(firefox) uses native structuredClone in firefox and does NOT serialize Error objects in config', {
        browser: 'firefox',
      }, function () {
        /**
           * NOTE: structuredClone() was introduced in Firefox 94. Supported versions below 94 need to use the ponyfill
           * to determine whether or not a value can be serialized through postMessage. Since the ponyfill deems Errors
           * as clonable, but postMessage does not in Firefox, this test will fail and will fail all subsequent tests since the
           * config is not serializable.
           *
           * The likelihood that a user is going to be placing Error objects in Cypress.config() or Cypress.env() in versions of Firefox 93 and below
           * is rare. That being said, for Firefox versions below 94, this test will be skipped.
           */
        if (Cypress.browser.majorVersion < 94) {
          this.skip()
        }

        Cypress[fnName]('errorInConfig', new Error('error'))

        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const isUndefined = Cypress[fnName]('errorInConfig')

          expect(isUndefined).to.be.undefined
        })
      })

      // NOTE: chrome 98 and above uses a native structuredClone() method, but that method CAN clone Error objects
      it('(chromium) uses ponyfilled or native structuredClone that can serialize Error objects in config', {
        browser: ['electron', 'chrome', 'chromium', 'edge'],
      }, () => {
        Cypress[fnName]('errorInConfig', new Error('error'))

        cy.switchToDomain('foobar.com', [fnName], ([fnName]) => {
          const isErrorObj = Cypress[fnName]('errorInConfig')

          expect(isErrorObj).to.be.an.instanceof(Error)
        })
      })
    })
  })
})
