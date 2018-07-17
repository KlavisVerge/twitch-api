require('dotenv/config');
const AWS = require('aws-sdk');
const request = require('request-promise');
AWS.config.update({region: 'us-east-1'});

exports.handler = (event, context) => {
    if(event){
        if(!event.body){
            event.body = {};
        }else if(typeof event.body === 'string'){
            event.body = JSON.parse(event.body);
        }
    }
    const required = ['gameName'].filter((property) => !event.body[property]);
    if(required.length > 0){
        return Promise.reject({
            statusCode: 400,
            message: `Required properties missing: "${required.join('", "')}".`
        });
    }
    let promises = [];
    var options = {
        url: 'https://api.twitch.tv/helix/games?name=' + event.body.gameName,
        headers: {
            'Client-ID': process.env.CLIENT_ID
        }
    };
    promises.push(request(options).promise().then((res) => {
        return res;
    }).catch(function (err) {
        return Promise.reject({
            statusCode: err.statusCode,
            message: 'Error interacting with Twitch API.'
        });
    }));

    return Promise.all(promises).then((responses) => {
        const[resultsOuter] = responses;
        let promisesInner = [];
        var streams = {
            url: 'https://api.twitch.tv/helix/streams?game_id=' + JSON.parse(resultsOuter).data[0].id,
            headers: {
                'Client-ID': process.env.CLIENT_ID
            }
        };
        promisesInner.push(request(streams).promise().then((res) => {
            return res;
        }).catch(function (err) {
            return Promise.reject({
                statusCode: err.statusCode,
                message: 'Error interacting with Twitch API.'
            });
        }));

        return Promise.all(promisesInner).then((responses) => {
            let parsed = JSON.parse(resultsOuter);
            const[results] = responses;
            const retObj = {
              "game": parsed,
              "streams": results
            };
            return context.succeed({
                statusCode: 200,
                body: JSON.stringify(results),
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Methods': 'POST',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,XAmz-Security-Token',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        });
    });
};