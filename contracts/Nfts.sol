// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Nfts is ERC1155, VRFConsumerBaseV2 {
    // ERRORS

    // EVENTS
    event packBought(address indexed _address, uint256 _requestId);
    event packOpened(
        address indexed _address,
        uint256 _requestId,
        uint256 _nftId
    );
    event itemAdded(NFTtype _type, uint256 _nftId, string _name);
    event earnedReward(address indexed _address, uint256 _amount);

    // COINS
    uint256 public constant rewardCoins = 0;

    uint256[] public avatarNfts; //1,2,3,...

    uint256 public packPrice;
    address private owner;

    // VRF
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;
    bytes32 s_keyHash;
    uint32 s_callbackGasLimit;
    uint16 constant s_requestConfirmations = 3;
    uint32 constant s_numWords = 2;

    // NFTTYPE for targeting body part
    enum NFTtype {
        avatarSkin, //12%
        avatarUpperBody, //22%
        avatarLowerBody, //22%
        avatarShoes, //22%
        avatarAccessories //22%
    }

    // DESCRIPTION OF TOKEN IDS
    struct NftDescription {
        string name;
        // Chance to get it,
        // Limited supply,
    }

    // Mapping nft type to all token ids that are made for the type
    mapping(NFTtype => uint256[]) public NFTtypes;

    // Mapping token id to their description
    mapping(uint256 => NftDescription) public NFTDescriptions;

    // MAPPING TO STORE AUTHORIZED CONTRACTS(GAMES AND CONTENT)
    mapping(address => bool) public authorizedContracts;

    // OWNER MODIFIER
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "The address doesnt have permission to call this function"
        );
        _;
    }

    // CONTRACT AUTHORIZATION MODIFIER TO CHECK IF THE EXTERNAL CONTRACTS CAN CALL OUR FUNCTION
    modifier isAuthorized() {
        require(
            authorizedContracts[msg.sender] == true,
            "The address is not part of authorized contracts"
        );
        _;
    }

    // NEED TO ADD THE IPFS TOKEN URI
    constructor(
        uint64 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint256 _packPrice
    )
        ERC1155("https://ipfs.io/ipfs/HASH_HERE/{id}.json")
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        owner = msg.sender;
        s_subscriptionId = subscriptionId;
        s_keyHash = keyHash;
        s_callbackGasLimit = callbackGasLimit;
        packPrice = _packPrice;
    }

    // DOES THE NFT EXIST, string or the nftId
    function doesNFTOptionExist(
        uint256 nftId,
        string memory nftName
    ) public view returns (bool) {
        bool result = false;
        for (uint256 i = 0; i < avatarNfts.length; i++) {
            if (avatarNfts[i] == nftId) {
                result = true;
                break;
            } else if (
                keccak256(bytes(NFTDescriptions[avatarNfts[i]].name)) ==
                keccak256(bytes(nftName))
            ) {
                result = true;
                break;
            }
        }
        return result;
    }

    // ADD NEW NFT
    function addNewNFTOption(
        NFTtype _type,
        uint256 newId,
        string memory newName
    ) public onlyOwner {
        require(
            doesNFTOptionExist(newId, newName) == false,
            "This nft option already exists"
        );
        avatarNfts.push(newId);
        NFTDescriptions[newId] = NftDescription(newName);
        NFTtypes[_type].push(newId);

        emit itemAdded(_type, newId, newName);
    }

    // CALL THIS FUNCTION TO BUY PACKS WITH REWARDCOINS
    // To reduce the cost of calling vrf each pack, we could buy multiple at once
    function buyPack(address _address) external {
        require(
            waitingForResponse[_address] == false,
            "The address is waiting for response"
        );
        super._burn(_address, 0, packPrice);
        uint256 requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackGasLimit,
            s_numWords
        );
        getRequestAddress[requestId] = _address;
        waitingForResponse[_address] = true;

        emit packBought(_address, requestId);
    }

    // GET THE RANDOM NUMBER BACK
    mapping(uint256 => address) public getRequestAddress;
    mapping(address => bool) public waitingForResponse;

    // GET ITEM BACK FROM BUYING A PACK (VRF RANDOM NUMBER)
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // RANDOM NUMBER FROM 1-100
        uint256 result = ((randomWords[0] % 99) + 1);

        // TO GET NFT TYPE
        uint256 currentChance = 0;
        NFTtype resulttype;
        uint8[5] memory chances = getChanceArray();
        for (uint256 i = 0; i < chances.length; i++) {
            if (result > currentChance && result < chances[i]) {
                resulttype = NFTtype(i);
                break;
            }
            currentChance = chances[i];
        }

        // GET NFT ID, uint256 of the nft option
        uint256 nftId = NFTtypes[resulttype][
            ((randomWords[1] % (NFTtypes[resulttype].length - 1)) + 1) // -1 and +1 to be between 1 and length
        ];

        // MINT THE NFT ID
        super._mint(getRequestAddress[requestId], nftId, 1, "");
        waitingForResponse[getRequestAddress[requestId]] = false;

        emit packOpened(getRequestAddress[requestId], requestId, nftId);
    }

    // CHANCE FOR DIFFERENT NFT TYPES
    function getChanceArray() public pure returns (uint8[5] memory) {
        return [12, 34, 56, 78, 100];
    }

    // CALL THIS FUNCTION TO MINT NEW TOKENS
    // Figure out how we are going to distribute the reward tokens, if we are going to have distribution in this contract
    function earnRewards(
        address _address,
        uint256 amount
    ) external isAuthorized {
        super._mint(_address, 0, amount, "");
        emit earnedReward(_address, amount);
    }

    // CHANGE PACK PRICE, if random events occur to give our players discounts
    // If we want to give certain players discount we can do mappings of price for each player
    // Could include upkeep(time) if we want to
    function setPackPrice(uint256 newPrice) external onlyOwner {
        packPrice = newPrice;
    }

    // AUTHORIZES THE CONTRACT TO CALL OUR FUNCTIONS
    // If needed can add that only a contract can be authorized, no addresses, for transparency reasons
    function authorizeContract(address _address) external onlyOwner {
        authorizedContracts[_address] = true;
    }

    // GIVE DISCOUNT TO A CERTAIN PLAYER IF THEY UNLOCK CERTAIN ACHIVEMENTS
    // mapping of address and discount
    // function to change the discount of a player

    // TOKEN URI
    function uri(
        uint256 _tokenId
    ) public pure override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "https://ipfs.io/HASH_HERE/",
                    Strings.toString(_tokenId),
                    ".json"
                )
            );
    }

    // URI for entire contract
    function contractURI() public pure returns (string memory) {
        return "https://ipfs.io/ipfs/HASH_HERE/collection.json";
    }

    //GET A RANDOM POWER UP
    // Could be called if the user reaches a certain milestone, could also make it a pack
    function getPowerUp() external isAuthorized {}
}
