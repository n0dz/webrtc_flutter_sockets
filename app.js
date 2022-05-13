const express = require('express');

const app = express();

const PORT = process.env.PORT || 3478;

const server = app.listen(PORT, () => {
    console.log('Server Started on Port ', PORT);
});

const io = require('socket.io')(server);

io.on('connection',(socket) => {
    console.log('Connected Succesfully', socket.id);
    socket.on('disconnect', () => {
    console.log('Disconnected', socket.id);
    });

    socket.on('offer', (data) => {
            console.log(data);
            socket.broadcast.emit('offer-received', data);
            console.log('Offer Sent from Server');
            console.log(data);
        });


    socket.on('answer', (data) => {
            console.log(data);
            socket.broadcast.emit('answer-received', data);
            console.log('Answer Sent from Server');
            console.log(data);
        });
    socket.on('roomID', (data) => {
                console.log(data);
                socket.broadcast.emit('roomID-sent', data);
                 console.log(data);
        });

    socket.on('candidate', (data) => {
            console.log(data);
            console.log('Candidate data Sent from Server');
            socket.broadcast.emit('candidate-sent', data);
        });

    socket.on('calleeCandidate', (data) => {
            console.log(data);
            console.log('Caller Candidate data Sent from Server');
            socket.broadcast.emit('calleeCandidate-sent', data);
    });

});
