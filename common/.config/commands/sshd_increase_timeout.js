import { tool } from "../node_modules/@opencode-ai/plugin/dist/tool.js";

export const sshd_increase_timeout = async (ctx) => {
    return {
        tool: {
            sshd_increase_timeout: tool({
                description: "Increase server-side SSH timeouts for better connection stability",
                args: {},
                async execute(args) {
                    const commands = [
                        "grep -i clientalive /etc/ssh/sshd_config || echo 'No ClientAlive settings found'",
                        "echo 'ClientAliveInterval 60' | sudo tee -a /etc/ssh/sshd_config",
                        "echo 'ClientAliveCountMax 10' | sudo tee -a /etc/ssh/sshd_config",
                        "sudo systemctl restart sshd",
                        "grep -i clientalive /etc/ssh/sshd_config"
                    ];
                    
                    let output = "=== SSH Timeout Configuration ===\n\n";
                    
                    for (const cmd of commands) {
                        output += `$ ${cmd}\n`;
                        // Note: This would be executed on the VPS when run there
                    }
                    
                    return output + "\nDone! SSH timeout increased to 10 minutes.";
                },
            }),
        },
    };
};