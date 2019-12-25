import { PermissionsAndroid, Platform, NativeModules } from 'react-native'

const SCAN_PERMISSIONS = [
  PermissionsAndroid.PERMISSIONS.CAMERA,
  PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
  PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE
]

const { DocScanner } = NativeModules

/**
 * Original implementations:
 * android - https://github.com/jhansireddy/AndroidScannerDemo
 * ios - https://github.com/WeTransfer/WeScan
 */
class Scanner {
  async scan(mode: 'select' | 'camera' | 'gallery'): Promise<string | undefined> {
    const granted = await this.requestPermissions()
    if (!granted) {
      return undefined
    }

    try {
      const scannedFileUri = await DocScanner.startScan(mode)
      return scannedFileUri
    } catch (error) {
      console.warn(error)
      return undefined
    }
  }

  private async requestPermissions(): Promise<boolean> {
    if (Platform.OS === 'ios') {
      return true
    }

    const results = await PermissionsAndroid.requestMultiple(SCAN_PERMISSIONS)
    return Object.values(results).reduce<boolean>(
      (prev, current) => prev && current === PermissionsAndroid.RESULTS.GRANTED,
      true
    )
  }
}

export default Scanner
