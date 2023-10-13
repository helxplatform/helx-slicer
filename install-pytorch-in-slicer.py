
import PyTorchUtils

torchLogic = PyTorchUtils.PyTorchUtilsLogic()
minimumTorchVersion="1.12"
if not torchLogic.torchInstalled():
    print('PyTorch Python package is required. Installing... (it may take several minutes)')
    torch = torchLogic.installTorch(askConfirmation=False, forceComputationBackend="cu121", torchVersionRequirement = f">={minimumTorchVersion}")
    if torch is None:
        raise ValueError('PyTorch extension needs to be installed to use this module.')
exit()
