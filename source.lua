gotest = package.loaded['gotest']
gotest.cleanup()
package.loaded['gotest'] = nil
package.loaded['gotest.sign'] = nil

require('gotest')
print("loaded gotest")
