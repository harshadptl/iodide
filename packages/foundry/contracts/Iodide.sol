pragma solidity >=0.8.0 <0.9.0;

// Useful for debugging. Remove when deploying to a live network.
import "forge-std/console.sol";

// Use openzeppelin to inherit battle-tested implementations (ERC20, ERC721, etc)
// import "@openzeppelin/contracts/access/Ownable.sol";

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Iodide is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    struct Campaign {
        address manager;
        bytes32 name;
        uint256 fundsBalance;
        bytes32 messageHash;
        uint targetViews;
        uint isActive;
    }

    struct Post {
        uint256 campaignID;
        bytes16 handle;
        address influencer;
        string tweetID;
        CampaignPostState state;
        bytes32 verificationRequestID;
    }

    struct Pair{
        uint256 campaignID;
        address influencer;
    }

    enum CampaignPostState{ APPLIED, APPROVED, PROOF_POSTED, VERIFIED_AND_PAID}

    Campaign[] public campaigns;
    uint256 public nCampaigns;

    mapping(uint256 => mapping(address => Post)) public campaignPosts;
    mapping(bytes32 => Pair) public verificationRequestPost;

    string source = "const verifyURL = 'https://grownlinedimplementation.harshadpatil8.repl.co/tweet/verify'"
    "const tweetID = args[0]"
    "const hash = args[1]"
    "const targetViews = args[2]"
    "console.log(`Sending HTTP request to ${verifyURL}/${tweetID}/${hash}/${targetViews}`)"
    "const request = Functions.makeHttpRequest({"
    "url: `${verifyURL}/${tweetID}/${hash}/${targetViews}`,"
    "method: 'GET',"
    "})"
    "const Response = await request"
    "if (Response.error) {"
    "console.log(Response)"
    "throw Error('Request failed, try checking the params provided')"
    "}"
    "const reqData = Response.data"
    "if (reqData.data.success ){"
    "return Functions.encodeUint256(1)"
    "} else {"
    "return Functions.encodeUint256(0)"
    "}";

    uint64 private chainlinkSubscriptionID = 475;
    bytes32 private jobId = bytes32("fun-polygon-mumbai-1");

    constructor(
        address router
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {}

    function launchCampaign(
        bytes32 _name,
        uint256 _funds,
        string memory _message,
        uint _targetViews
    ) public payable returns (uint256) {

        require(_funds > 500, 'Not enough funds committed');
        require(msg.value > _funds, 'Not enough contribution to funds');

        bytes32 _messageHash = keccak256(bytes(_message));

        campaigns.push(Campaign(
                msg.sender,
                _name,
                _funds,
                _messageHash,
                _targetViews,
                1
            ));

        nCampaigns += 1;
        return nCampaigns;
    }

    function applyCampaignPost(uint256 _campaignID, bytes16 _handle) payable public {

        require(msg.value > 1, 'need 1 MATIC to apply');

        Post memory post = Post(
            _campaignID,
            _handle,
            msg.sender,
            "",
            CampaignPostState.APPLIED,
            bytes32(0)
        );

        campaignPosts[_campaignID][msg.sender] = post;
    }

    function approveCampaignPost(uint256 _campaignID, address _influencer) public {
        Campaign storage c = campaigns[_campaignID];

        require(c.manager == msg.sender, 'Only manager can approve a influencer');
        require(c.isActive == 1, 'Campaign not active');

        Post storage post = campaignPosts[_campaignID][_influencer];

        require(post.state == CampaignPostState.APPLIED);
        post.state = CampaignPostState.APPROVED;

    }

    function proveCampaignPost(uint256 _campaignID, string memory _tweetID) public {

        address _influencer = msg.sender;
        Post storage post = campaignPosts[_campaignID][_influencer];

        require(post.state == CampaignPostState.APPROVED);
        post.tweetID = _tweetID;
        post.state = CampaignPostState.PROOF_POSTED;

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);

        Campaign storage c = campaigns[_campaignID];

        string[] memory args = [_tweetID, Strings.toString(c.messageHash), Strings.toString(c.targetViews)];
        req.setArgs(args);

        post.verificationRequestID = _sendRequest(
            req.encodeCBOR(),
            chainlinkSubscriptionID,
            300000,
            jobId
        );


    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {

    }

    function getCampaign(uint256 _id) public view returns (Campaign memory) {
        return campaigns[_id];
    }

}