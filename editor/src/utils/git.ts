import { spawn } from 'child_process';

class Git {

/// Run

    run(args:Array<string>, cwd:string, done:(code:number, stdout:string, stderr:string) => void) {

        let proc = spawn('git', args, { cwd: cwd });

        let out = '';
        let err = '';

        proc.stdout.on('data', (data) => {
            out += data;
        });

        proc.stderr.on('data', (data) => {
            err += data;
        });

        proc.on('error', (error) => {
            console.error(error);
        });

        proc.on('close', (code) => {
            done(code, out, err);
        });

    } //run

} //Git

export const git = new Git();
