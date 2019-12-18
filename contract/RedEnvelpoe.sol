pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import './SafeMath.sol';
import './Owned.sol';

/**
 * @dev 墨客社区红包
 *
 * 功能：1、发红包；2、抢红包；3、抢红包记录查询
 * 限制：1、只支持moac交易；2、owner代抢（防止恶意刷红包）
 */
contract RedEnvelope is Owned {
    using SafeMath for uint256;

    uint256 private MIN = 1000000000000;

    struct _RedEnvelope {
        address master;
        uint256 amount;
        uint256 balance;
        uint8 number;
        uint256 createTime;
    }

    struct _GrabHistory {
        address master;
        uint256 amount;
        uint256 grabTime;
    }

    mapping(address => mapping(bytes32 => bool)) internal grabStage;
    mapping(bytes32 => _RedEnvelope) internal redEnvelopes;
    mapping(address => _GrabHistory[]) internal grabHistories;

    event Award(address indexed master, uint256 indexed amount, uint256 indexed createTime, uint8 number);
    event Grab(address indexed participant,bytes32 indexed redId, uint256 amount);

    function() public {
        revert();
    }

    /**
     * @dev 发红包
     *
     * @param _redKey 红包口令
     * @param _number 红包个数
     */
    function award(string _redKey, uint8 _number) public payable returns (bool) {
        require(msg.value > 0, "Not allowed to empty");
        bytes32 id = sha256(abi.encode(_redKey, msg.sender));
        uint256 createTime = now;
        redEnvelopes[id] = _RedEnvelope(msg.sender, msg.value, msg.value, _number, createTime);
        emit Award(msg.sender, msg.value, createTime, _number);
        return true;
    }

    /**
     * @dev 抢红包
     *
     * @param _redKey 红包口令
     * @param _master 红包
     * @param participant 参与者
     */
    function grab(string _redKey,address _master, address participant) public onlyOwner returns (bool){
        bytes32 redId = sha256(abi.encode(_redKey, _master));
        _RedEnvelope memory redEnvelope = redEnvelopes[redId];
        require(redEnvelope.balance > 0, "The red envelope is empty");
        require(!grabStage[participant][redId], "Be grabbed");
        uint256 amount;
        if (redEnvelope.number > 1) {
            amount = randomRatio(redEnvelope,participant);
        } else {
            amount = redEnvelope.balance;
        }
        redEnvelopes[redId] = redEnvelope;
        grabHistories[participant].push(_GrabHistory(redEnvelope.master, amount, now));
        grabStage[participant][redId] = true;
        participant.transfer(amount);
        emit Grab(participant, redId, amount);
        return true;
    }

    /**
     * @dev 随机红包生成
     *
     * @param redEnvelope 红包
     * @param participant 参与者
     */
    function randomRatio(_RedEnvelope redEnvelope,address participant) private view returns (uint256) {
        uint256 _randomRatio = uint256(keccak256(abi.encodePacked(redEnvelope.number, participant, now))) % 100;
        uint256 max = redEnvelope.balance.div(redEnvelope.number).mul(2);
        uint256 amount = max.mul(_randomRatio).div(100);
        amount = amount < MIN ? MIN : amount;
        redEnvelope.balance = redEnvelope.balance.sub(amount);
        redEnvelope.number = redEnvelope.number - 1;
        return amount;
    }

    /**
     * @dev 未抢空红包剩余金额返还
     *
     * @param _now 执行时间
     */
    function withDraw(uint256 _now) public onlyOwner returns (bool) {

        // todo 考虑基数过大，造成交易失败

        _RedEnvelope memory redEnvelope;
        if (_now.sub(redEnvelope.createTime) >= 24 hours && redEnvelope.balance > 0) {
            uint256 _balance = redEnvelope.balance;
            redEnvelope.balance = 0;
            redEnvelope.master.transfer(_balance);
        }

        return true;
    }

    /**
     * @dev 抢红包记录查询
     */
    function historicalQuery() public view returns (_GrabHistory[]) {
        return grabHistories[msg.sender];
    }

}