pragma solidity ^0.8.9;

import { Suave } from "lib/suave-std/src/suavelib/Suave.sol";


abstract contract SuaveContract {
	error SuaveError(string message);
	error SuaveErrorWithData(string message, bytes data);

	modifier onlyConfidential() {
		crequire(Suave.isConfidential(), "Not confidential");
		_;
	}

	function crequire(bool condition, string memory message) internal pure {
		if (!condition) {
			revert SuaveError(message);
		}
	}
}
