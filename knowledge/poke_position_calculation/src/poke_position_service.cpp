#include "ros/ros.h"
#include "object_detection/PokeObject.h"
#include "json_prolog/prolog.h"
#include <string>
#include <sstream>
#include <marker_publisher/marker_publisher.h>
#include <tf/transform_listener.h>
  
using namespace json_prolog;

class PokePositionService
{
private:

	tf::TransformListener listener;
    geometry_msgs::PointStamped visionPoint;
    geometry_msgs::PointStamped transformedPoint;
    geometry_msgs::PointStamped knowledgePoint;

    geometry_msgs::Point calculate(const int direction)
    {
        geometry_msgs::Point point;
        switch(direction)
        {
            case object_detection::PokeObject::Request::DIRECTION_LEFT: point.x = transformedPoint.point.x+0.09;
                                                                        point.y = transformedPoint.point.y+0.09;
                                                                        point.z = transformedPoint.point.z+0.06;
            break;
            case object_detection::PokeObject::Request::DIRECTION_RIGHT: point.x = transformedPoint.point.x+0.09;
                                                                         point.y = transformedPoint.point.y-0.09;
                                                                         point.z = transformedPoint.point.z+0.06;
            break;
            default: point.x = transformedPoint.point.x+0.09;
                     point.y = transformedPoint.point.y+0.09;
                     point.z = transformedPoint.point.z+0.06;
        }

        return point;
    }

public:

    geometry_msgs::PointStamped getVisionPoint() const
    {
        return visionPoint;
    }

    geometry_msgs::PointStamped getTransformedPoint() const
    {
        return transformedPoint;
    }

    geometry_msgs::PointStamped getKnowledgePoint() const
    {
        return knowledgePoint;
    }
	
    bool calculate_poke_position(object_detection::PokeObject::Request  &req, object_detection::PokeObject::Response &res)
    {
	    ROS_INFO_STREAM("Input from vison frame_id: " << req.detection.position.header.frame_id);
        ROS_INFO("Input from vison x: %g", req.detection.position.point.x);
        ROS_INFO("Input from vison y: %g", req.detection.position.point.y);
        ROS_INFO("Input from vison z: %g", req.detection.position.point.z);
        visionPoint = req.detection.position;

        ROS_INFO("Transform point to odom_combined");

        try
        {
        	listener.transformPoint("/odom_combined", req.detection.position, transformedPoint);
        }
        catch (tf::TransformException &ex) 
        {
        	res.error_message = "Failed to call service 'calculate_poke_position'. Transformation failed!";
         	return false;
        }
	   
        ROS_INFO_STREAM("Transformed point frame_id: " << transformedPoint.header.frame_id);
        ROS_INFO("Transformed point x: %g", transformedPoint.point.x);
        ROS_INFO("Transformed point y: %g", transformedPoint.point.y);
        ROS_INFO("Transformed point z: %g", transformedPoint.point.z);
	   
        res.poke_position.header = transformedPoint.header;
        res.poke_position.point = calculate(req.direction);
    	res.error_message = "";
            
		ROS_INFO_STREAM("Modified point frame_id: " << res.poke_position.header.frame_id);
    	ROS_INFO("Modified result from knowledge x: %g", res.poke_position.point.x);
    	ROS_INFO("Modified result from knowledge y: %g", res.poke_position.point.y);
    	ROS_INFO("Modified result from knowledge z: %g", res.poke_position.point.z);
    	ROS_INFO_STREAM("Errormessage: " << res.error_message);
        knowledgePoint = res.poke_position;

        return true;
    }
};
   
int main(int argc, char **argv)
{
    ros::init(argc, argv, "poke_position_service");
    ros::NodeHandle nh("~");
   
   	PokePositionService pokePositionService;
    ros::ServiceServer service = nh.advertiseService("calculate_poke_position", &PokePositionService::calculate_poke_position, &pokePositionService);
        
    MarkerPublisher vision_marker_publisher("vision", Color::BLUE);
    MarkerPublisher transformed_marker_publisher("transform", Color::WHITE);
    MarkerPublisher knowledge_marker_publisher("knowledge", Color::PURPLE);

    ros::Rate rate(10);
    while(ros::ok())
    {
        vision_marker_publisher.publishVisualizationMarker(pokePositionService.getVisionPoint());
        transformed_marker_publisher.publishVisualizationMarker(pokePositionService.getTransformedPoint());
        knowledge_marker_publisher.publishVisualizationMarker(pokePositionService.getKnowledgePoint());
        
        ros::spinOnce();
        rate.sleep();
    }
   
    return 0;
}