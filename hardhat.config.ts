import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig, task } from "hardhat/config";
import dotenv from "dotenv";
import { z } from "zod";

dotenv.config();
const envSchema = z.object({
    GETBLOCKIO_API_KEY: z.string(),
    BSC_SCAN_API_KEY: z.string(),
    PRIVATE_KEY: z.string(),
    PRIVATE_KEY_OTHER: z.string(),
});
const result = envSchema.safeParse(process.env);

if (!result.success) {
    console.error("Environment variables missing check `.env.example`");
    process.exit(1);
}
const { GETBLOCKIO_API_KEY, BSC_SCAN_API_KEY, PRIVATE_KEY, PRIVATE_KEY_OTHER } = result.data;

interface DeployTaskArgs {
    contract: string;
    args?: string[];
}

task("deploy", "Deploys given contract")
    .addPositionalParam("contract", "The contract to deploy")
    .addOptionalVariadicPositionalParam(
        "args",
        "The arguments to pass to the constructor"
    )
    .setAction(async ({ contract, args }: DeployTaskArgs, hre) => {
        let constructorArguments = args || [];

        await hre.run("compile");
        const { sourceName, abi } = await hre.artifacts.readArtifact(contract);

        const constructorAbi = abi.find((abi) => abi.type === "constructor");
        if (constructorAbi) {
            const argSpec: string[] = constructorAbi.inputs.map(
                (input: { name: string }) =>
                    input.name
                        .substring(1)
                        .replace(/([A-Z])/g, " $1")
                        .replace(/^./, (str) => str.toUpperCase())
            );
            if (constructorArguments.length !== argSpec.length) {
                throw new Error(
                    `Expected ${argSpec.length} arguments, got ${constructorArguments.length}`
                );
            }
            if (argSpec.length) {
                console.log(
                    `Deploying ${contract} from ${sourceName} with arguments:`
                );
                argSpec.forEach((arg, i) => {
                    console.log(`- ${arg}\t${constructorArguments[i]}`);
                });
            }
        }

        const [deployer] = await hre.ethers.getSigners();
        console.log(`Deployer address: ${deployer.address}`);

        const ContractFactory = await hre.ethers.getContractFactory(contract);
        const Contract = await ContractFactory.deploy(...constructorArguments);
        await Contract.deployed();

        console.log(`Deployed ${contract} at ${Contract.address}`);

        await hre.run("verify:verify", {
            address: Contract.address,
            contract: `${sourceName}:${contract}`,
            constructorArguments,
        });
    });

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.16",
        settings: {
            viaIR: true,
            optimizer: {
                enabled: true,
                runs: 1000,
            },
        },
    },
    networks: {
        mainnet: {
            url: "https://bsc.getblock.io/mainnet/",
            chainId: 56,
            gasPrice: 20000000000,
            accounts: [PRIVATE_KEY],
            httpHeaders: {
                "x-api-key": GETBLOCKIO_API_KEY,
            },
        },
        testnet: {
            url: "https://bsc.getblock.io/testnet/",
            chainId: 97,
            gasPrice: 20000000000,
            accounts: [PRIVATE_KEY_OTHER],
            httpHeaders: {
                "x-api-key": GETBLOCKIO_API_KEY,
            },
        },
    },
    etherscan: {
        apiKey: {
            bscTestnet: BSC_SCAN_API_KEY,
            bsc: BSC_SCAN_API_KEY,
        },
    },
};

export default config;
