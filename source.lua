gotest = package.loaded['gotest']
gotest.cleanup()
package.loaded['gotest'] = nil
package.loaded['gotest.sign'] = nil
package.loaded['gotest.ui'] = nil
package.loaded['gotest.scan'] = nil

require('gotest')
print("loaded gotest")
