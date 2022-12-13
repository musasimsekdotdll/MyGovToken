const ContractName = artifacts.require("MyGov");

module.exports = function(deployer) {
deployer.deploy(ContractName);
};