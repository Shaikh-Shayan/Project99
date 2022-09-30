// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts@4.7.3/security/ReentrancyGuard.sol";
import "./NFTStorage.sol";

//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x23079599b4950D89429F1C08B2ed2DC820955Fd5"]
contract NFTMarketPlace is
    ERC1155,
    ERC1155Burnable,
    EIP712,
    Ownable,
    ReentrancyGuard
{
    event NFTPurchased(
        uint256 tokenId,
        uint256 nonce,
        uint256 copies,
        address buyer,
        uint256 amount
    );

    event Airdropped(address account, uint256 amount, uint256 tokenId);

    event Claimed(address account, uint256 amount, uint256 tokenId);

    event NFTBurned(address account, uint256 tokenId);

    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNING_VERSION = "1";

    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        uint256 copies;
        address artist;
        /*The signature proves that the NFT creator authorized the creation 
        of the specific NFT described in the voucher.
        */
        bytes signature;
    }

    //Contract Address of NFTStorage
    NFTStorage public NFTStorageContract;

    //Checks whether NFT with given tokenId exists
    modifier isValidId(uint256 tokenId) {
        require(
            NFTStorageContract.getNFTDetails(tokenId).isSet,
            "NFT DOESNT' EXISTS"
        );
        _;
    }

    constructor(address _NFTStorageAddress)
        ERC1155(
            "ipfs://bafybeidcf6zgua6jmzxpmhq6uey3izacstycsneeleyvhjnozmm5djyxcq/{id}.json"
        )
        EIP712(SIGNING_DOMAIN, SIGNING_VERSION)
    {
        NFTStorageContract = NFTStorage(_NFTStorageAddress);
    }

    /*
    function 'redeem' takes a voucher as an argument and lets the user redeem the signed voucher
    The NFTVoucher-type member 'voucher' takes voucher
    The address-type member 'account' takes buyer's address
    The uint256-type member 'nonce' takes nonce
    */
    function redeem(
        NFTVoucher calldata voucher,
        uint256 nonce,
        uint256 copies
    ) public payable nonReentrant isValidId(voucher.tokenId) {
        /*
        Check wether address is present in the allowlist
        */
        NFTStorage.NFTDetails memory NFT = NFTStorageContract.getNFTDetails(
            voucher.tokenId
        );

        address buyer = msg.sender;
        require(
            NFTStorageContract.getAllowlisted(voucher.tokenId, buyer),
            "ADDRESS NOT ALLOWLISTED"
        );
        /*
        Check if the signature is valid and belongs to the account that's authorized to mint NFTs
        */
        address signer = _verify(voucher);
        require(signer == voucher.artist, "INVALID SIGNER");

        /*
        Check to see if user has already used the signature
        */
        require(!NFTStorageContract.voucherUsed(nonce), "VOUCHER ALREADY USED");

        // require(
        //     voucher.tokenId == 1 || voucher.tokenId == 2,
        //     "Token doesn't exist"
        // );
        require(NFT.minted + copies <= NFT.maxCopies, "NOT ENOUGH NFT SUPPLY");
        require(
            msg.value >= NFT.price * copies * 1 wei,
            "NOT ENOUGH ETHERS SENT"
        );

        /*
        transferring the funds to the owner
        */
        payable(owner()).transfer(msg.value);

        /*
        minting NFT
        */
        _mint(buyer, voucher.tokenId, copies, "");
        NFT.minted += copies;
        NFTStorageContract.setVoucherUsed(nonce);

        /*
        airdropping Rewards NFTs to the NFT buyers
        */
        if (NFT.rewardNFTs.length != 0) {
            for (uint256 j = 0; j < NFT.rewardNFTs.length; j++) {
                NFTStorageContract.setAirdroppedAmount(
                    NFT.rewardNFTs[j],
                    buyer,
                    1
                );
            }
        }
        emit NFTPurchased(voucher.tokenId, nonce, copies, buyer, msg.value);
    }

    /*
    function 'checkElgibility' checks whether an account can claim the NFT with given tokenId
    The uint256-type member 'tokenId' takes the NFT token id
    The address-type member 'account' takes user's address
    Returns bool-type member indicating if the account can claim the NFT
    */
    function checkEligibility(uint256 tokenId, address account)
        public
        view
        isValidId(tokenId)
        returns (bool)
    {
        //check whether account is allowlisted to claim the NFT or not
        require(
            NFTStorageContract.getAllowlisted(tokenId, account),
            "ACCOUNT NOT ALLOWLISTED"
        );
        //check wthere account has already claimed the NFT or not
        require(
            NFTStorageContract.getClaimedAmount(tokenId, account) == 0,
            "NFT ALREADY CLAIMED"
        );

        return true;
    }

    /*
    The function 'claim' mints the nft to the address(msg.sender) who was aidropped the nft 
    The address-type input 'account' takes receiver's address
    The uint256-type input 'tokenId' takes Token ID
    */
    function claim(uint256 tokenId) external nonReentrant isValidId(tokenId) {
        address account = msg.sender;
        NFTStorage.NFTDetails memory NFT = NFTStorageContract.getNFTDetails(
            tokenId
        );

        //calculate the number of NFTs the user has left to claim
        uint256 amount = NFTStorageContract.getAirdroppedAmount(
            tokenId,
            account
        ) - NFTStorageContract.getClaimedAmount(tokenId, account);

        require(amount > 0, "NO NFT LEFT TO CLAIM");

        //mint the number of above calculated NFTs to the aacount
        _mint(account, tokenId, amount, "");
        NFT.minted += amount;

        NFTStorageContract.setClaimedAmount(tokenId, account, amount);

        emit Claimed(account, amount, tokenId);
    }

    /*
    The function 'burn' burns the nft only after 1 year
    The address-type input 'account' takes  address
    The uint256-type input 'id' takes Token ID
    The uint256-type input 'value' takes value
    */
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public override isValidId(id) {
        NFTStorage.NFTDetails memory NFT = NFTStorageContract.getNFTDetails(id);
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        /*
        Require statement checks that the time has exceeded burn rate, i.e., 1 year
        */
        require(
            block.timestamp > NFT.burnTime,
            "NFT CANNOT BE BURNED BEFORE 1 YEAR"
        );

        emit NFTBurned(account, id);
        super.burn(account, id, value);
    }

    /*
    The function '_beforeTokenTransfer' ensures that NFT is non-transferable 
    */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        NFTStorage.NFTDetails memory NFT = NFTStorageContract.getNFTDetails(
            ids[0]
        );
        require(NFT.isSet, "NFT DOESNT' EXISTS");
        if (NFT.isTransferrable) {
            super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        } else {
            require(
                from == address(0) || to == address(0),
                "THIS NFT IS NON-TRANSFERRABLE"
            );
        }
    }

    /*
    The function '_afterTokenTransfer' emits the event based on whether token is minted or burned.
    */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        NFTStorage.NFTDetails memory NFT = NFTStorageContract.getNFTDetails(
            ids[0]
        );
        require(NFT.isSet, "NFT DOESNT' EXISTS");

        if (NFT.isTransferrable) {
            super._afterTokenTransfer(operator, from, to, ids, amounts, data);
        }
    }

    /*
    The function '_verify' verifies signature against input and recovers address, 
    or reverts transaction if signature is invalid
    The NFTVoucher-type input 'voucher' takes voucher
    */
    function _verify(NFTVoucher calldata voucher)
        public
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    /*
    The function '_hash' returns the hash of the argument passed
    The NFTVoucher-type input 'voucher' takes voucher
    */
    function _hash(NFTVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "NFTVoucher(uint256 tokenId,uint256 minPrice,uint256 copies,address artist)"
                        ),
                        voucher.tokenId,
                        voucher.minPrice,
                        voucher.copies,
                        voucher.artist
                    )
                )
            );
    }
}
