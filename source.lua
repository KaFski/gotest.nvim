gotest = package.loaded['gotest']
gotest.cleanup()
package.loaded['gotest'] = nil

require('gotest')
